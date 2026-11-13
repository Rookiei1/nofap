require "base64"
require "openssl"
require "plist"
require "stringio"
require_relative "signing_identity"

# Local fixtures only. These keys are generated in memory and are not Apple identities.
key = OpenSSL::PKey::RSA.new(2048)
make_certificate = lambda do |serial|
  certificate = OpenSSL::X509::Certificate.new
  certificate.version = 2
  certificate.serial = serial
  certificate.subject = OpenSSL::X509::Name.parse("/CN=Offline profile fixture/OU=LOCALTEST1")
  certificate.issuer = certificate.subject
  certificate.public_key = key.public_key
  certificate.not_before = Time.now - 60
  certificate.not_after = Time.now + 3600
  certificate.sign(key, OpenSSL::Digest::SHA256.new)
  certificate
end

expected = make_certificate.call(1)
other = make_certificate.call(2)
der = expected.to_der.b
utf8_der = der.dup.force_encoding(Encoding::UTF_8)
raise "Fixture must preserve identical DER bytes" unless utf8_der.bytes == der.bytes
raise "Fixture did not exercise incompatible Ruby string encodings" if utf8_der == der

xml = <<~XML
  <?xml version="1.0" encoding="UTF-8"?>
  <plist version="1.0"><dict><key>DeveloperCertificates</key><array>
  <data>#{Base64.strict_encode64(der)}</data>
  </array></dict></plist>
XML
profile_certificates = Plist.parse_xml(xml, marshal: false).fetch("DeveloperCertificates")
NoFapSigning.verify_profile_certificate!(profile_certificates, expected: expected)
NoFapSigning.verify_profile_certificate!([utf8_der], expected: expected)
NoFapSigning.verify_profile_certificate!([der], expected: expected)
NoFapSigning.verify_profile_certificate!([expected.to_pem], expected: expected)

stream = StringIO.new(der)
stream.read
NoFapSigning.verify_profile_certificate!([stream], expected: expected)

begin
  NoFapSigning.verify_profile_certificate!([other.to_der], expected: expected)
  raise "A genuinely different certificate was accepted"
rescue RuntimeError => error
  raise unless error.message.start_with?("Profile is not bound to the verified existing certificate")
end

begin
  NoFapSigning.verify_profile_certificate!(["invalid certificate"], expected: expected)
  raise "Malformed certificate data was accepted"
rescue RuntimeError => error
  raise unless error.message == "Profile contains an invalid X.509 certificate"
end

begin
  NoFapSigning.verify_profile_certificate!([], expected: expected)
  raise "An empty certificate list was accepted"
rescue RuntimeError => error
  raise unless error.message.start_with?("Profile is not bound to the verified existing certificate")
end

puts "8 offline certificate checks passed."
