# Setting Up AWS IAM Identity Center

This guide walks through setting up IAM Identity Center (AWS SSO) to manage user access across your AWS Organization.

## Prerequisites

- AWS Organization is already set up
- You have access to the **management account** (303289350912)
- IAM Identity Center must be enabled in the same region as your Organization (typically `us-east-1`, but can be any region you choose)

## Step 1: Enable IAM Identity Center

1. Sign in to the **management account** in the AWS Console
2. Go to **IAM Identity Center**
3. Click **Enable**
4. Choose **Enable with AWS Organizations**

This creates a default Identity Center instance. Note the **access portal URL** — it will look like:
```
https://d-xxxxxxxxxx.awsapps.com/start
```

You can customize this later under **Settings > Identity source > Access portal URL** to something like:
```
https://ubisi.awsapps.com/start
```

## Step 2: Create a User

1. In IAM Identity Center, go to **Users > Add user**
2. Fill in:
   - **Username:** e.g. `jonathan`
   - **Email address:** your email (used for the setup invitation)
   - **First name / Last name**
3. Click **Next**, optionally add to a group (or skip for now)
4. Click **Add user**

The user will receive an email with a link to set their password and configure MFA.

## Step 3: Create a Permission Set

Permission sets define what a user can do in an account.

1. Go to **Permission sets > Create permission set**
2. Choose **Predefined permission set** for common ones:
   - **AdministratorAccess** — full admin (good for the initial setup user)
   - **ViewOnlyAccess** — read-only
   - **PowerUserAccess** — full access except IAM management
3. Or choose **Custom permission set** to define specific policies
4. Set the **session duration** (default 1 hour, up to 12 hours)
5. Click **Create**

You can create multiple permission sets (e.g. `AdministratorAccess` for admin tasks, `ReadOnlyAccess` for auditing).

## Step 4: Assign User to Account

1. Go to **AWS accounts**
2. Select your account (303289350912)
3. Click **Assign users or groups**
4. Select the user (or group) you created
5. Select the permission set(s) to grant
6. Click **Submit**

The user can now log in via the access portal and assume the assigned permission set in the account.

## Step 5: Set Up MFA

MFA is enforced by default for new users. On first login:

1. The user visits the access portal URL
2. Sets their password (from the invitation email)
3. Registers an MFA device (authenticator app or security key)

To adjust MFA settings:

1. Go to **Settings > Authentication**
2. Configure MFA requirements:
   - **Every time they sign in** (recommended)
   - **Only when sign-in context changes**
3. Choose allowed MFA types (authenticator apps, FIDO2 security keys, etc.)

## Step 6: Configure AWS CLI Access

Users can get temporary CLI credentials through the access portal or using `aws sso login`.

### One-time CLI setup

```bash
aws configure sso
```

Follow the prompts:
```
SSO session name (Recommended): ubisi
SSO start URL: https://ubisi.awsapps.com/start
SSO region: eu-west-1
SSO registration scopes [sso:account:access]:
```

This opens a browser for authentication. After approving, select the account and permission set. The CLI then prompts for a default profile name.

### Daily usage

```bash
# Log in (opens browser for SSO authentication)
aws sso login --sso-session ubisi

# Verify access
aws sts get-caller-identity

# Use a specific profile
aws s3 ls --profile my-profile-name
```

### Named profiles in `~/.aws/config`

After running `aws configure sso`, your config will look like:

```ini
[sso-session ubisi]
sso_start_url = https://ubisi.awsapps.com/start
sso_region = eu-west-1
sso_registration_scopes = sso:account:access

[profile ubisi-dev-admin]
sso_session = ubisi
sso_account_id = 303289350912
sso_role_name = AdministratorAccess
region = eu-west-1
```

You can add multiple profiles for different accounts or permission sets.

## Adding More Users Later

1. Create the user in IAM Identity Center
2. Optionally add them to a group
3. Assign the group (or user) to the relevant accounts with appropriate permission sets

## Using Groups for Scalable Access

Instead of assigning users individually to accounts, use groups:

1. Go to **Groups > Create group** (e.g. `Admins`, `Developers`, `ReadOnly`)
2. Add users to groups
3. Assign groups to accounts with permission sets

This way, when a new team member joins, you just add them to the right group.

## Troubleshooting

- **No invitation email:** Check spam, or go to Users > select user > Reset password to resend
- **CLI login fails:** Ensure the SSO region matches where Identity Center is enabled
- **"You do not have any applications":** The user hasn't been assigned to any account yet — complete Step 4
- **Session expired:** Run `aws sso login --sso-session ubisi` again
