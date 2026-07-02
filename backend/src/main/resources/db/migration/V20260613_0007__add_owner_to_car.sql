-- Add owner relationship to car table
ALTER TABLE car ADD COLUMN owner_id BIGINT NULL;
ALTER TABLE car ADD CONSTRAINT fk_car_owner FOREIGN KEY (owner_id) REFERENCES users(user_id) ON DELETE SET NULL;
CREATE INDEX idx_car_owner_id ON car(owner_id);
