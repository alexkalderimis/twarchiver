CREATE TABLE IF NOT EXISTS tweet (
    tweet_id TEXT PRIMARY KEY,
    text TEXT NOT NULL,
    retweeted BOOLEAN,
    retweeted_count INTEGER,
    favorited BOOLEAN,
    favorited_count INTEGER,
    tweeted_at DATETIME,
    twitter_account TEXT NOT NULL REFERENCES twitteraccount(screen_name),
    retweets TEXT REFERENCES twitteraccount(screen_name)
);

CREATE TABLE IF NOT EXISTS user (
    user_id INTEGER PRIMARY KEY,
    passhash TEXT,
    username TEXT NOT NULL,
    preferred_page_size INTEGER,
    last_login DATETIME,
    created_at DATETIME,
    twitter_account TEXT REFERENCES twitteraccount(screen_name)
);

create TABLE IF NOT EXISTS twitteraccount (
    last_update DATETIME,
    twitter_id TEXT,
    screen_name TEXT PRIMARY KEY,
    friends_count INTEGER,
    tweet_total INTEGER,
    created_at DATETIME,
    profile_image_url TEXT,
    profile_bkg_url TEXT,
    access_token TEXT,
    access_token_secret TEXT,
    user INTEGER REFERENCES user(user_id)
);

CREATE TABLE IF NOT EXISTS tweet_mention (
    id INTEGER PRIMARY KEY,
    tweet INTEGER REFERENCES tweet(tweet_id),
    mention TEXT REFERENCES twitteraccount(screen_name)
);

CREATE TABLE IF NOT EXISTS tweet_hashtag (
    id INTEGER PRIMARY KEY,
    tweet INTEGER REFERENCES tweet(tweet_id),
    hashtag INTEGER REFERENCES hashtag(hashtag_id)
);

CREATE TABLE IF NOT EXISTS hashtag (
    hashtag_id INTEGER PRIMARY KEY,
    last_update DATETIME,
    topic TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS tweet_tag (
    id INTEGER PRIMARY KEY,
    tweet INTEGER REFERENCES tweet(tweet_id),
    tag INTEGER REFERENCES tag(tag_id),
    private_to INTEGER REFERENCES user(user_id)
    tagger INTEGER NOT NULL DEFAULT 0 REFERENCES user(user_id)
);

CREATE TABLE IF NOT EXISTS tag (
    tag_id INTEGER PRIMARY KEY,
    tag_text TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS tweet_url (
    id INTEGER PRIMARY KEY,
    tweet INTEGER REFERENCES tweet(tweet_id),
    url INTEGER REFERENCES url(url_id)
);

CREATE TABLE IF NOT EXISTS url (
    url_id INTEGER PRIMARY KEY,
    address TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS betakey (
    key_id INTEGER PRIMARY KEY,
    key TEXT NOT NULL,
    user_id INTEGER REFERENCES user(user_id)
);

