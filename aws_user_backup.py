#!/usr/bin/env python3
import boto3
import json
import sys
from datetime import datetime

def get_user_details(username):
    """Extract complete IAM user details for recreation"""
    iam = boto3.client('iam')
    
    try:
        # Get user basic info
        user = iam.get_user(UserName=username)['User']
        
        # Get user policies (inline)
        inline_policies = []
        policy_names = iam.list_user_policies(UserName=username)['PolicyNames']
        for policy_name in policy_names:
            policy = iam.get_user_policy(UserName=username, PolicyName=policy_name)
            inline_policies.append({
                'PolicyName': policy_name,
                'PolicyDocument': policy['PolicyDocument']
            })
        
        # Get attached managed policies
        attached_policies = iam.list_attached_user_policies(UserName=username)['AttachedPolicies']
        
        # Get groups
        groups = iam.get_groups_for_user(UserName=username)['Groups']
        
        # Get access keys (metadata only, not secret keys)
        access_keys = iam.list_access_keys(UserName=username)['AccessKeyMetadata']
        
        # Get user tags
        try:
            tags = iam.list_user_tags(UserName=username)['Tags']
        except:
            tags = []
        
        # Get login profile (console access)
        login_profile = None
        try:
            login_profile = iam.get_login_profile(UserName=username)['LoginProfile']
        except iam.exceptions.NoSuchEntityException:
            pass
        
        # Get MFA devices
        mfa_devices = iam.list_mfa_devices(UserName=username)['MFADevices']
        
        # Get signing certificates
        certificates = iam.list_signing_certificates(UserName=username)['Certificates']
        
        # Get SSH public keys
        ssh_keys = iam.list_ssh_public_keys(UserName=username)['SSHPublicKeys']
        
        # Get service specific credentials
        service_creds = iam.list_service_specific_credentials(UserName=username)['ServiceSpecificCredentials']
        
        return {
            'User': {
                'UserName': user['UserName'],
                'Path': user['Path'],
                'CreateDate': user['CreateDate'].isoformat(),
                'UserId': user['UserId'],
                'Arn': user['Arn'],
                'Tags': user.get('Tags', [])
            },
            'InlinePolicies': inline_policies,
            'AttachedPolicies': [{'PolicyArn': p['PolicyArn'], 'PolicyName': p['PolicyName']} for p in attached_policies],
            'Groups': [g['GroupName'] for g in groups],
            'AccessKeys': [{'AccessKeyId': ak['AccessKeyId'], 'Status': ak['Status'], 'CreateDate': ak['CreateDate'].isoformat()} for ak in access_keys],
            'Tags': tags,
            'LoginProfile': {
                'CreateDate': login_profile['CreateDate'].isoformat(),
                'PasswordResetRequired': login_profile.get('PasswordResetRequired', False)
            } if login_profile else None,
            'MFADevices': [{'SerialNumber': mfa['SerialNumber'], 'EnableDate': mfa['EnableDate'].isoformat()} for mfa in mfa_devices],
            'SigningCertificates': [{'CertificateId': cert['CertificateId'], 'Status': cert['Status']} for cert in certificates],
            'SSHPublicKeys': [{'SSHPublicKeyId': key['SSHPublicKeyId'], 'Status': key['Status']} for key in ssh_keys],
            'ServiceSpecificCredentials': service_creds,
            'BackupDate': datetime.now().isoformat()
        }
        
    except Exception as e:
        print(f"Error getting user details: {e}")
        return None

def save_user_backup(username, output_file=None):
    """Save user details to JSON file"""
    details = get_user_details(username)
    if not details:
        return False
    
    if not output_file:
        output_file = f"{username}_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    
    with open(output_file, 'w') as f:
        json.dump(details, f, indent=2, default=str)
    
    print(f"User backup saved to: {output_file}")
    return True

def print_recreation_commands(backup_file):
    """Generate AWS CLI commands to recreate the user"""
    with open(backup_file, 'r') as f:
        data = json.load(f)
    
    user = data['User']
    username = user['UserName']
    
    print(f"\n# Commands to recreate user: {username}")
    print(f"aws iam create-user --user-name {username} --path {user['Path']}")
    
    # Add to groups
    for group in data['Groups']:
        print(f"aws iam add-user-to-group --user-name {username} --group-name {group}")
    
    # Attach managed policies
    for policy in data['AttachedPolicies']:
        print(f"aws iam attach-user-policy --user-name {username} --policy-arn {policy['PolicyArn']}")
    
    # Create inline policies
    for policy in data['InlinePolicies']:
        print(f"aws iam put-user-policy --user-name {username} --policy-name {policy['PolicyName']} --policy-document '{json.dumps(policy['PolicyDocument'])}'")
    
    # Add tags
    if data['Tags']:
        tags_str = ' '.join([f"Key={tag['Key']},Value={tag['Value']}" for tag in data['Tags']])
        print(f"aws iam tag-user --user-name {username} --tags {tags_str}")
    
    # Create login profile (console access)
    if data['LoginProfile']:
        print(f"aws iam create-login-profile --user-name {username} --password <NEW_PASSWORD> --password-reset-required")
    
    print(f"\n# Note: Access keys, MFA devices, and certificates must be recreated manually")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python aws_user_backup.py <username> [output_file]")
        print("       python aws_user_backup.py --restore <backup_file>")
        sys.exit(1)
    
    if sys.argv[1] == "--restore":
        if len(sys.argv) < 3:
            print("Please provide backup file for restore")
            sys.exit(1)
        print_recreation_commands(sys.argv[2])
    else:
        username = sys.argv[1]
        output_file = sys.argv[2] if len(sys.argv) > 2 else None
        save_user_backup(username, output_file)