require 'travis/support/encrypted_column'
require 'travis/support/secure_config'

class SslKey < ActiveRecord::Base
  serialize :private_key, Travis::EncryptedColumn.new

  def encode(string)
    Base64.encode64(encrypt(string)).strip
  end

  def encrypt(string)
    key.public_encrypt(string)
  end

  def decrypt(string)
    key.private_decrypt(string)
  end

  private

    def key
      @key ||= OpenSSL::PKey::RSA.new(private_key)
    end
end
