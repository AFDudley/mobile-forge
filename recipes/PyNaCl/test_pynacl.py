import nacl.utils
import nacl.secret
import nacl.public
import nacl.signing

def test_random():
    """Test random number generation"""
    data = nacl.utils.random(16)
    assert len(data) == 16
    assert isinstance(data, bytes)

def test_secret_box():
    """Test symmetric encryption"""
    key = nacl.utils.random(nacl.secret.SecretBox.KEY_SIZE)
    box = nacl.secret.SecretBox(key)
    
    message = b"Hello, Apple platforms!"
    nonce = nacl.utils.random(nacl.secret.SecretBox.NONCE_SIZE)
    encrypted = box.encrypt(message, nonce)
    decrypted = box.decrypt(encrypted)
    
    assert message == decrypted

def test_public_key():
    """Test asymmetric encryption"""
    sender_key = nacl.public.PrivateKey.generate()
    sender_box = nacl.public.Box(sender_key, sender_key.public_key)
    
    message = b"Cross-platform secure messaging"
    nonce = nacl.utils.random(nacl.public.Box.NONCE_SIZE)
    encrypted = sender_box.encrypt(message, nonce)
    decrypted = sender_box.decrypt(encrypted)
    
    assert message == decrypted

def test_signing():
    """Test digital signatures"""
    signing_key = nacl.signing.SigningKey.generate()
    signed = signing_key.sign(b"Sign me!")
    verify_key = signing_key.verify_key
    message = verify_key.verify(signed)
    
    assert message == b"Sign me!"

if __name__ == "__main__":
    test_random()
    test_secret_box()
    test_public_key()
    test_signing()
    print("All tests passed!")