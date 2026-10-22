import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy policy',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.accentCyan.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accentCyan.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_rounded,
                              color: AppColors.accentCyan, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Play Friends Privacy Policy',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Updated on: February 2, 2026',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.trophyGold,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Operated by ssgobind.space',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlueLight,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Overview
              _buildParagraph(
                'Welcome to Play Friends (referred to as "Play Friends" or "the App"). Play Friends is owned and operated by ssgobind.space (referred to as "Play Friends," "we," or "us"). This Privacy Policy outlines how we protect your personal data, which is of utmost importance to you. The following topics are covered in this policy:\n\n'
                '• Information Collection and Acquisition: We explain what information we collect and the methods we employ to collect it.\n\n'
                '• Information Usage and Sharing: We detail how we use the collected information and with whom we share it.\n\n'
                '• Accessing and Updating Your Information: We provide guidance on how you can access and update the information we hold about you.\n\n'
                '• Information Storage Protection: We outline the measures we take to safeguard the information we store about you.\n\n'
                'We encourage you to carefully read this Privacy Policy to understand how Play Friends handles your personal data.\n\n'
                'Play Friends collects personal information from its users, such as their nickname, gender, and date of birth. Users have control over their user profile and can access their "Profile" page to correct or update their information. By accessing or using Play Friends, users agree to the Privacy Policy and consent to the collection, storage, use, and disclosure of their personal information as outlined in the Policy. Play Friends reserves the right to change the Policy without notice, so users are encouraged to regularly check for updates. If a user does not accept or agree with the Privacy Policy, they should not access or use the app.\n\n'
                'To join Play Friends, you will need to provide us with information about yourself to facilitate easier friend-making. This includes your nickname, gender, and date of birth. You have full control over your user profile, and you can access your "Profile" page at any time to view and update your details by simply logging into Play Friends.',
              ),

              const SizedBox(height: 18),
              _buildSectionTitle(
                  '1. What information does Play Friends collect?'),
              _buildSubSectionTitle('(1) Information provided by Users'),
              _buildParagraph(
                'a. Your mobile number and SMS verification code: We will send a verification code to your mobile number via SMS to confirm your identity. Failure to provide the verification code will result in a failed registration, and you will not be able to use our services. Please note that the mobile number you provide will serve as your user account and identity credential for logging in.\n\n'
                'b. Password: You must set a login password for your account as part of the verification process.\n\n'
                'c. Date of Birth: Prior to registering a Play Friends account, you must provide your date of birth to determine if you meet the qualifications for user registration. If you are a minor, you are not permitted to use the Play Friends app or services.\n\n'
                'd. Gender: During the registration process, you must provide your gender. This information allows us to help customize your user experience and display gender-identifying information on your profile as per your choice. Failure to provide this information will result in a failed registration, and you will not be able to use the Play Friends app or services.\n\n'
                'e. User Profile: You may create your profile by creating your avatar with the tool provided by us, setting your nickname, region and providing a self-introduction of you.\n\n'
                'f. Content uploaded by users: When uploading Posts or commenting on other users’ Posts, you agree to share with us the text information posted, pictures, audio and video uploaded. If you do not want to provide such information, please do not use functions related to content publication. To maintain a safe environment, we will identify and filter objectionable content. We reserve the right to remove any content that violates our community standards.\n\n'
                'g. Chat: You may use Play Friends Services to chat with other registered users, freely choose between text chat and/or voice chat according to your need. We collect your activity information including with whom you have talked, at which time and for how long. Unless specifically required by applicable laws, we will not access to the chat content including your text and/or voice information. If you do not want to provide such information, please do not use functions related to chatting.\n\n'
                'h. Help & Support: If you have any feedback or suggestion or want to express your complaint, you may provide your comments through “Settings” - “Help & feedback” within our App. You will need to describe the issue, upload proof photos, text to help us understand your issues and find corresponding solutions. And we will receive your ticket of feedback also reply back.\n\n'
                'i. Safety Controls (Report & Block): Users can report inappropriate content or behavior through the "Help & feedback" section or directly within the chat interface. We also provide a "Block" feature that allows you to instantly hide all content from a specific user. All reports will be reviewed and addressed within 24 hours.',
              ),

              const SizedBox(height: 12),
              _buildSubSectionTitle(
                  '(2) Personal information automatically collected during the use of our App'),
              _buildParagraph(
                'When you use Play Friends, we will collect certain information from your device, including device model, device ID (Android ID, IMEI, IMSI, Mac address), software list, device running status information, operating system version, network log, internet connection situation, software usage records and IP address. We collect such information to perform bug analysis and take anti-spam measures, to ensure your normal use of Play Friends, and to safeguard your account security. The information mentioned above is the basic information we need to provide you with our services. If you refuse to provide such device information, we may not be able to provide you with the normal services.\n\n'
                'We may also use the above mentioned information we collect automatically from your device to improve and optimize our product experience. In such circumstances, we will only process your device information based on your authorization and/or other available lawful basis provided in applicable data protection laws.',
              ),

              const SizedBox(height: 12),
              _buildSubSectionTitle('(3) Information we receive from others'),
              _buildParagraph(
                'Users are required to provide their mobile number, SMS verification code, password, date of birth, and gender during the registration process for Play Friends. This information is necessary for identity verification, account creation, and establishing your user profile. Minors are not permitted to use the Play Friends app or services.\n\n'
                'In addition to information provided directly, Play Friends may receive information through social media or third-party accounts (such as Facebook, Google, or Apple) as authorized by the user, including basic profile details like name, profile picture, email address, and publicly available information.',
              ),

              const SizedBox(height: 18),
              _buildSectionTitle(
                  '2. System permission inquired by Play Friends'),
              _buildParagraph(
                '(1) In order to provide you with Play Friends services, we may need to be granted permission to your system to collect relevant personal information.\n\n'
                '(2) Push Notification: After you grant us permission to push notification, we will send you push notifications for you to receive and understand notices in time.\n\n'
                '(3) Access to photo album and storage: Allows you to upload texts, pictures, and avatar photos, and cache media. We do not access unrelated local storage content.\n\n'
                '(4) Access to microphone: Enables voice input and voice party room chat features. Microphone access is active only while using voice features.',
              ),

              const SizedBox(height: 18),
              _buildSectionTitle('3. How we use your information'),
              _buildParagraph(
                'a. help you efficiently access your information after you sign in;\n\n'
                'b. remember information so you will not have to re-enter it during your visit or the next time you visit the Service;\n\n'
                'c. provide personalized content and information to you and others;\n\n'
                'd. provide, improve, test, and monitor the effectiveness of our Service;\n\n'
                'e. develop and test new products and features;\n\n'
                'f. monitor metrics such as total number of visitors, traffic, and demographic patterns;\n\n'
                'g. diagnose or fix technology problems;\n\n'
                'h. automatically update the App on your device.',
              ),

              const SizedBox(height: 18),
              _buildSectionTitle('4. How We Share Your Information'),
              _buildParagraph(
                'a. We do not sell or rent out any personal information about users to any third party. Play Friends discloses aggregated non-personal data for marketing and promotional purposes.\n\n'
                'b. If your profile is public, your content will be visible to other players on Play Friends.\n\n'
                'c. We may share information with members, subsidiaries, or affiliates of our corporate group to improve and optimize Play Friends.\n\n'
                'd. We may share your Personal Information outside of Play Friends Services when we have your consent, either express or implied.\n\n'
                'e. We may disclose Personal Information to authorized service providers that perform certain services on our behalf (cloud storage, analytics, payment processing, fraud prevention).\n\n'
                'f. Disclosures in the event of a merger, acquisition, restructuring, or asset transfer will ensure consistent privacy standards.\n\n'
                'g. We access, preserve, and share Personal Information with regulators, law enforcement, or others when required to comply with applicable laws, legal processes, or prevent harm.',
              ),

              const SizedBox(height: 18),
              _buildSectionTitle('5. Data Storage'),
              _buildParagraph(
                'Play Friends operates through secure servers located in multiple countries, including Singapore. By submitting your information or using Play Friends applications, you agree to the transfer, storage, and processing of your personal information in these jurisdictions under strict security protocols.',
              ),

              const SizedBox(height: 18),
              _buildSectionTitle('6. Security'),
              _buildParagraph(
                'Play Friends has implemented reasonable and appropriate security measures to protect and prevent the loss, misuse, and alteration of information under our control, including secured firewalls, encrypted storage, and authenticated session tokens.\n\n'
                'You must keep your password secure and not disclose it to any third parties. If you believe your password or credentials have been compromised, please report it immediately through Settings > Help & feedback.',
              ),

              const SizedBox(height: 18),
              _buildSectionTitle('7. Account Deletion'),
              _buildParagraph(
                'You may request deletion of your account at any time through:\n\n'
                'a. Play Friends App: Open Play Friends App and log in, Tap Settings > Delete account > Confirm to delete your account; or\n\n'
                'b. Website: Visit Play Friends official portal, navigate to "Delete Account", log in, and confirm.\n\n'
                'Before submitting a request to delete your account, please ensure your account satisfies:\n'
                '• Account in Good Standing: No ongoing investigations, penalties, or violations;\n'
                '• No outstanding transactions: No pending orders, payment obligations, or unresolved disputes;\n'
                '• Virtual Items: Ensure you have used or agreed to forfeit remaining virtual coin balances;\n\n'
                'Upon confirmation, your account and associated personal data will be deleted or irreversibly disassociated in accordance with applicable laws.',
              ),

              const SizedBox(height: 18),
              _buildSectionTitle('8. Your Rights'),
              _buildParagraph(
                'Some jurisdictions grant specific data rights to Play Friends users, including the right to access, correct, update, or request deletion of personal information. You may submit a request by using Help & feedback within the App or by contacting us at playgamefriendes@gmail.com.',
              ),

              const SizedBox(height: 18),
              _buildSectionTitle('Contact Us'),
              _buildParagraph(
                'If you have questions or concerns regarding this Privacy Policy or your data, please contact our privacy compliance team:',
              ),
              const SizedBox(height: 10),

              // Contact Email Card
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Clipboard.setData(
                      const ClipboardData(text: 'playgamefriendes@gmail.com'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Support email copied: playgamefriendes@gmail.com 📋'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.accentCyan.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.mark_email_read_rounded,
                          color: AppColors.accentCyan, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Privacy & Support Email',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              'playgamefriendes@gmail.com',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.copy_rounded,
                          color: AppColors.accentCyan, size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: AppColors.accentCyan,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildSubSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.trophyGold,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
        height: 1.5,
      ),
    );
  }
}
