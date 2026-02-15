-- Remove students.address after initial production data exists.
ALTER TABLE students
    DROP COLUMN IF EXISTS address;
