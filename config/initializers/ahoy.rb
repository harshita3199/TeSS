class Ahoy::Store < Ahoy::DatabaseStore
end

# set to true for JavaScript tracking
Ahoy.api = true

# set to true for geocoding (and add the geocoder gem to your Gemfile)
# we recommend configuring local geocoding as well
# see https://github.com/ankane/ahoy#geocoding
Ahoy.geocode = false

# GDPR compliance
Ahoy.mask_ips = true
Ahoy.cookies = false

# Disable automatic server-side visit tracking
Ahoy.server_side_visits = :when_needed