CREATE TABLE tweet (
    tweet_id TEXT PRIMARY KEY,
    text TEXT NOT NULL,
    retweeted BOOLEAN,
    retweeted_count INTEGER,
    favorited BOOLEAN,
    favorited_count INTEGER,
    created_at DATETIME,
    user INTEGER NOT NULL REFERENCES user(user_id)
);

CREATE TABLE user (
    user_id INTEGER PRIMARY KEY,
    twitter_id TEXT,
    screen_name TEXT,
    friends_count INTEGER,
    created_at DATETIME,
    profile_image_url TEXT,
    profile_bkg_url TEXT,
    access_token TEXT,
    access_token_secret TEXT,
    passhash TEXT,
    username TEXT NOT NULL,
    preferred_page_size INTEGER,
    last_login DATETIME
);

CREATE TABLE tweet_mention (
    id INTEGER PRIMARY KEY,
    tweet INTEGER REFERENCES tweet(tweet_id),
    mention INTEGER REFERENCES mention(mention_id)
);

CREATE TABLE mention (
    mention_id INTEGER PRIMARY KEY,
    mention_name TEXT NOT NULL
);

CREATE TABLE tweet_hashtag (
    id INTEGER PRIMARY KEY,
    tweet INTEGER REFERENCES tweet(tweet_id),
    hashtag INTEGER REFERENCES hashtag(hashtag_id)
);

CREATE TABLE hashtag (
    hashtag_id INTEGER PRIMARY KEY,
    topic TEXT NOT NULL
);

CREATE TABLE tweet_tag (
    id INTEGER PRIMARY KEY,
    tweet INTEGER REFERENCES tweet(tweet_id),
    tag INTEGER REFERENCES tag(tag_id)
);

CREATE TABLE tag (
    tag_id INTEGER PRIMARY KEY,
    tag_text TEXT NOT NULL
);

CREATE TABLE tweet_url (
    id INTEGER PRIMARY KEY,
    tweet INTEGER REFERENCES tweet(tweet_id),
    url INTEGER REFERENCES url(url_id)
);

CREATE TABLE url (
    url_id INTEGER PRIMARY KEY,
    address TEXT NOT NULL
);

