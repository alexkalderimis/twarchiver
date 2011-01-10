CREATE INDEX tweet_mention_tweet_index ON tweet_mention(tweet);
CREATE INDEX tweet_mention_mention_index ON tweet_mention(mention);

CREATE INDEX tweet_hashtag_tweet_index ON tweet_hashtag(tweet);
CREATE INDEX tweet_hashtag_hashtag_index ON tweet_hashtag(hashtag);

CREATE INDEX hashtag_topic_index ON hashtag(topic);

CREATE INDEX tweet_tag_tweet_index ON tweet_tag(tweet);
CREATE INDEX tweet_tag_tag_index ON tweet_tag(tag);

CREATE INDEX tag_tag_index ON tag(tag_text);

CREATE INDEX tweet_url_address_index ON tweet_url(url);
CREATE INDEX tweet_url_tweet_index ON tweet_url(tweet);

CREATE INDEX url_address_index ON url(address);

