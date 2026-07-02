-- Fix booking.status enum: add CONFIRMED and IN_PROGRESS values missing from initial schema
ALTER TABLE booking
    MODIFY COLUMN status ENUM('PENDING','CONFIRMED','IN_PROGRESS','COMPLETED','CANCELLED') NOT NULL DEFAULT 'PENDING';
