ALTER TABLE tweet_tag ADD COLUMN tagger INTEGER NOT NULL DEFAULT 0 REFERENCES user(user_id);
