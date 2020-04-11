module ShareOnFacebookFilter
  def facebook_share_url(url)
    url = url_encode(url)
    "https://www.facebook.com/sharer/sharer.php?u=#{url}"
  end
end

Liquid::Template.register_filter(ShareOnFacebookFilter)
