module ShareOnTwitterFilter
  def twitter_share_url(url)
    url = url_encode(url)
    "http://twitter.com/share?url=#{url}"
  end

  def twitter_with_text(twitter_url, text)
    text = url_encode(text)
    twitter_url + "&text=#{text}"

  end

  def twitter_with_hashtags(twitter_url, hashtags)
    hashtags = hashtags.split(',') if hashtags.is_a?(String)

    twitter_url + '&hashtags=' + hashtags.map { |h| url_encode(h) }.join(',')
  end
end

Liquid::Template.register_filter(ShareOnTwitterFilter)
