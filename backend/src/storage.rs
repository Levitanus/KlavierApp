use std::io::{ErrorKind, Result as IoResult};
use std::path::PathBuf;
use std::pin::Pin;
use std::sync::Arc;

use async_trait::async_trait;
use bytes::Bytes;
use futures_util::{future, Stream, StreamExt};
use tokio::io::AsyncWriteExt;
use tokio_util::io::ReaderStream;
use uuid::Uuid;

pub type ByteStream = Pin<Box<dyn Stream<Item = Result<Bytes, std::io::Error>>>>;

#[derive(Debug, Clone)]
pub struct StoredFile {
    pub key: String,
    pub url: String,
}

#[derive(Debug)]
pub enum MediaError {
    InvalidFileType,
    TooLarge,
    Io(std::io::Error),
}

#[async_trait(?Send)]
pub trait StorageProvider: Send + Sync {
    async fn put(&self, key: &str, data: ByteStream) -> IoResult<()>;
    async fn get(&self, key: &str) -> IoResult<ByteStream>;
    async fn delete(&self, key: &str) -> IoResult<()>;
    fn public_url(&self, key: &str) -> String;
}

#[derive(Clone)]
pub struct LocalStorage {
    root_dir: PathBuf,
    public_base: String,
}

impl LocalStorage {
    pub fn new(root_dir: PathBuf, public_base: String) -> Self {
        Self {
            root_dir,
            public_base,
        }
    }
}

#[async_trait(?Send)]
impl StorageProvider for LocalStorage {
    async fn put(&self, key: &str, mut data: ByteStream) -> IoResult<()> {
        let path = self.root_dir.join(key);
        let mut file = tokio::fs::File::create(&path).await?;

        let mut write_result: IoResult<()> = Ok(());
        while let Some(chunk) = data.next().await {
            match chunk {
                Ok(bytes) => {
                    if let Err(err) = file.write_all(&bytes).await {
                        write_result = Err(err);
                        break;
                    }
                }
                Err(err) => {
                    write_result = Err(err);
                    break;
                }
            }
        }

        if let Err(err) = file.flush().await {
            write_result = Err(err);
        }

        if write_result.is_err() {
            let _ = tokio::fs::remove_file(&path).await;
        }

        write_result
    }

    async fn get(&self, key: &str) -> IoResult<ByteStream> {
        let path = self.root_dir.join(key);
        let file = tokio::fs::File::open(&path).await?;
        let stream = ReaderStream::new(file).map(|chunk| chunk.map(Bytes::from));
        Ok(Box::pin(stream))
    }

    async fn delete(&self, key: &str) -> IoResult<()> {
        let path = self.root_dir.join(key);
        match tokio::fs::remove_file(&path).await {
            Ok(_) => Ok(()),
            Err(err) if err.kind() == ErrorKind::NotFound => Ok(()),
            Err(err) => Err(err),
        }
    }

    fn public_url(&self, key: &str) -> String {
        let base = self.public_base.trim_end_matches('/');
        format!("{}/{}", base, key)
    }
}

#[derive(Clone)]
pub struct MediaService {
    provider: Arc<dyn StorageProvider>,
    max_profile_image_size: u64,
}

impl MediaService {
    pub fn new(provider: Arc<dyn StorageProvider>) -> Self {
        Self {
            provider,
            max_profile_image_size: 5 * 1024 * 1024,
        }
    }

    pub async fn save_profile_image<S>(
        &self,
        username: &str,
        extension: &str,
        stream: S,
    ) -> Result<StoredFile, MediaError>
    where
        S: Stream<Item = Result<Bytes, std::io::Error>> + 'static,
    {
        let safe_ext = extension.trim_start_matches('.').to_lowercase();
        if !matches!(safe_ext.as_str(), "jpg" | "jpeg" | "png" | "gif" | "webp") {
            return Err(MediaError::InvalidFileType);
        }

        let filename = format!("{}_{}.{}", username, Uuid::new_v4(), safe_ext);
        let size_limit = self.max_profile_image_size;

        let limited_stream = stream.scan(0u64, move |size, chunk| {
            let next = match chunk {
                Ok(bytes) => {
                    *size += bytes.len() as u64;
                    if *size > size_limit {
                        Err(std::io::Error::new(
                            ErrorKind::InvalidData,
                            "File too large",
                        ))
                    } else {
                        Ok(bytes)
                    }
                }
                Err(err) => Err(err),
            };

            future::ready(Some(next))
        });

        if let Err(err) = self
            .provider
            .put(&filename, Box::pin(limited_stream))
            .await
        {
            if err.kind() == ErrorKind::InvalidData {
                return Err(MediaError::TooLarge);
            }
            return Err(MediaError::Io(err));
        }

        Ok(StoredFile {
            key: filename.clone(),
            url: self.provider.public_url(&filename),
        })
    }

    pub async fn delete_profile_image(&self, key: &str) -> Result<(), MediaError> {
        self.provider
            .delete(key)
            .await
            .map_err(MediaError::Io)
    }
}
