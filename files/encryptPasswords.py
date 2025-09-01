#!/usr/bin/env python3
"""
Password encryption script for CSO Shared Services Portal
Uses PBEWITHSHA256AND256BITAES-CBC-BC algorithm for password encryption
"""

import json
import sys
import base64
import hashlib
from Crypto.Cipher import AES
from Crypto.Protocol.KDF import PBKDF2
from Crypto.Random import get_random_bytes

def encrypt_password(password, encryption_key):
    """
    Encrypt password using PBEWITHSHA256AND256BITAES-CBC-BC algorithm
    Compatible with Java's PBEWithSHA256And256BitAES-CBC-BC
    """
    if not encryption_key or encryption_key.strip() == "":
        return password
    
    # Generate salt and IV
    salt = get_random_bytes(16)
    iv = get_random_bytes(16)
    
    # Derive key using PBKDF2 with SHA256
    key = PBKDF2(encryption_key, salt, 32, count=1000, hmac_hash_module=hashlib.sha256)
    
    # Encrypt password
    cipher = AES.new(key, AES.MODE_CBC, iv)
    
    # Pad password to multiple of 16 bytes
    padding_length = 16 - (len(password) % 16)
    padded_password = password + chr(padding_length) * padding_length
    
    encrypted = cipher.encrypt(padded_password.encode('utf-8'))
    
    # Combine salt + iv + encrypted data and encode as base64
    result = base64.b64encode(salt + iv + encrypted).decode('utf-8')
    
    return result

def main():
    """Main function to process password encryption"""
    try:
        # Read input from stdin
        input_data = json.loads(sys.stdin.read())
        
        encryption_key = input_data.get('encryption_key', '')
        
        # If no encryption key provided, return original passwords
        if not encryption_key or encryption_key.strip() == "":
            output = {
                'service_password': input_data.get('service_password', ''),
                'keystore_password': input_data.get('keystore_password', ''),
                'db_password': input_data.get('db_password', ''),
                'rabbitmq_password': input_data.get('rabbitmq_password', ''),
                'keystone_password': input_data.get('keystone_password', '')
            }
        else:
            # Encrypt all passwords
            output = {
                'service_password': encrypt_password(input_data.get('service_password', ''), encryption_key),
                'keystore_password': encrypt_password(input_data.get('keystore_password', ''), encryption_key),
                'db_password': encrypt_password(input_data.get('db_password', ''), encryption_key),
                'rabbitmq_password': encrypt_password(input_data.get('rabbitmq_password', ''), encryption_key),
                'keystone_password': encrypt_password(input_data.get('keystone_password', ''), encryption_key)
            }
        
        # Output JSON result
        print(json.dumps(output))
        
    except Exception as e:
        # Return error in JSON format
        error_output = {
            'error': str(e),
            'service_password': '',
            'keystore_password': '',
            'db_password': '',
            'rabbitmq_password': '',
            'keystone_password': ''
        }
        print(json.dumps(error_output))
        sys.exit(1)

if __name__ == '__main__':
    main()