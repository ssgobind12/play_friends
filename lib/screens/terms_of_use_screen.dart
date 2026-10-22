import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Terms of use',
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
                    color: AppColors.primaryPurple.withValues(alpha: 0.4),
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
                            color:
                                AppColors.primaryPurple.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.description_rounded,
                              color: AppColors.accentCyan, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User Agreement',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Last Updated: 05-09-2026',
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

              // Introduction
              _buildParagraph(
                'Welcome to Play Friends (the "Platform" or "App"). Play Friends is owned and operated by ssgobind.space. These Terms of Service (the "Terms") constitute a legally binding agreement between you ("You" or "User") and ssgobind.space, the owner and operator of the Platform and App. By accessing or using the Platform or any of its services, features, or content, you acknowledge that you have read, understood, and agree to be bound by these Terms.\n\n'
                'This Agreement explains your rights and obligations as a user of the Platform and the terms under which Play Friends provides access to its services, features, and content. Whether you are a registered user, a guest, or simply browsing the Platform, these Terms govern your use of Play Friends.\n\n'
                'If you do not agree with any part of these Terms, you must stop using the Platform and exit the App immediately. Please read these Terms carefully before using Play Friends. We also recommend that you review our Privacy Policy, which explains how we collect, use, and protect personal data.',
              ),

              const SizedBox(height: 16),
              _buildSectionTitle('1. Special Notices'),
              _buildParagraph(
                '1.1 This Play Friends User Agreement (this "Agreement") governs your use of our services (the "Services"). For the purposes of this Agreement, you and Play Friends may be referred to together as the "Parties" and individually as a "Party".\n\n'
                '1.2 By using our Services or clicking "Sign Up" during registration, you agree to all terms of this Agreement. We may revise this Agreement from time to time at our sole discretion. The current version will be made available through Settings > User Agreement. Your continued use of the Services after any update means that you accept the revised Agreement.\n\n'
                '1.3 You may use our Services only if you are 16 years of age or older and are not otherwise restricted by applicable laws or regulations from entering into this Agreement. If you are below the applicable minimum age, you may use Play Friends only with valid consent from your parent or legal guardian. You must not falsely represent your age or eligibility.\n\n'
                '1.4 You are responsible for keeping your Play Friends account and password secure. All actions taken through your Play Friends account will be deemed to have been taken by you, and you are responsible for such actions.',
              ),

              const SizedBox(height: 16),
              _buildSectionTitle('2. Services Content'),
              _buildParagraph(
                'Play Friends may modify, update, suspend, or discontinue any part of the Services at its discretion, with or without notice. Some Services may require payment. If you choose not to pay for paid features or services, Play Friends is not obligated to provide those paid features or services to you.\n\n'
                'Play Friends may need to perform repairs, maintenance, upgrades, or technical adjustments. If such activities cause an interruption to paid Services, Play Friends will make reasonable efforts to provide notice where appropriate, but will not be liable for interruptions caused by maintenance or technical requirements.\n\n'
                'Play Friends may suspend, terminate, or restrict your access to the Services if you are underage, violate these Terms, engage in prohibited conduct, fail to make required payments, or otherwise use the Services in a way that may harm Play Friends, other users, or third parties.',
              ),

              const SizedBox(height: 16),
              _buildSectionTitle('3. Privacy'),
              _buildParagraph(
                'You acknowledge that you have read, understood, and agreed to our Privacy Policy, which explains how we collect, use, store, share, and protect your personal data.\n\n'
                'The Privacy Policy also explains your rights regarding your personal data, including access, correction, deletion, and other rights that may be available under applicable laws.\n\n'
                'If you have any questions or concerns regarding how your data is handled, please contact us at playgamefriendes@gmail.com.',
              ),

              const SizedBox(height: 16),
              _buildSectionTitle('4. Paid Services & Virtual Items'),
              _buildParagraph(
                'The App may offer paid services, features, and content, including premium features, virtual items, in-app currency, virtual rewards, and other offerings designed to enhance your user experience. By purchasing or using any paid Services, you agree to comply with this Agreement and any additional terms that apply to the relevant paid Services.\n\n'
                'Payments will be processed through our designated third-party payment processors. By making a purchase, you authorize the applicable payment processor to charge your selected payment method for the relevant fees. You are responsible for ensuring that your payment information is accurate and up to date.\n\n'
                'Unless otherwise required by applicable law, all payments for paid Services are non-refundable. Once a payment is processed, it cannot be refunded, even if you stop using the Services, delete your account, or choose not to use the purchased feature or item. Play Friends reserves the right to modify, suspend, or discontinue any paid Services, including pricing, features, availability, and payment methods.',
              ),

              const SizedBox(height: 10),

              // Highlighted Box for Virtual Items & Currency (English & Arabic)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.coinAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.coinAmber.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.monetization_on_rounded,
                            color: AppColors.coinAmber, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Virtual Items and In-App Currency',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.coinAmber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Any virtual reward items—such as gold coins or in-game currency—are strictly non-redeemable for cash, non-transferable via peer-to-peer transfers, and may not be used outside of the application.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'أي عناصر مكافآت افتراضية مثل العملات الذهبية أو عملات الألعاب داخل التطبيق مخصصة للاستخدام داخل التطبيق فقط، ولا يمكن استبدالها أو تحويلها إلى نقود. كما لا يجوز تحويلها بين المستخدمين أو استخدامها خارج التطبيق.',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFFDE047),
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              _buildSectionTitle('5. Terminating Services'),
              _buildParagraph(
                'You may terminate your use of Play Friends Services and this Agreement at any time by deleting or revoking your Play Friends account, subject to the account deletion procedures available in the App.\n\n'
                'After termination, you may no longer have access to the features and services provided by the App. Data associated with your account may be deleted, retained, or restricted in accordance with our Privacy Policy and applicable laws.',
              ),

              const SizedBox(height: 16),
              _buildSectionTitle('6. Disclaimers'),
              _buildParagraph(
                '6.1 You are solely responsible for any risks arising from your use of Play Friends Services. Your use of or reliance on the Services is at your own risk.\n\n'
                '6.2 Play Friends does not guarantee that the Services will meet your expectations or requirements, or that the Services will be uninterrupted, timely, secure, accurate, complete, or error-free. The Services are provided on an "as is" and "as available" basis.\n\n'
                '6.3 To the fullest extent permitted by applicable law, Play Friends makes no express or implied warranties regarding the operation, quality, availability, accuracy, completeness, or reliability of the Services or any part of them.\n\n'
                '6.4 Play Friends is not responsible for external links, third-party websites, or third-party resources that may be accessed through the Services. Such links are provided for convenience only and do not imply endorsement by Play Friends. Play Friends is not liable for any loss or damage arising from your access to or use of third-party websites or resources.\n\n'
                '6.5 Play Friends will not be liable for interruptions, delays, failures, or deficiencies in the Services caused by events beyond its reasonable control, including force majeure, technical failures, network issues, legal or regulatory requirements, or actions of third parties. Where reasonably possible, Play Friends will make efforts to reduce the impact of such events.',
              ),

              const SizedBox(height: 16),
              _buildSectionTitle('7. Content'),
              _buildSubSectionTitle('7.1 Play Friends Content'),
              _buildParagraph(
                'All content, software, images, text, graphics, designs, materials, features, and other elements provided by Play Friends through the Services are owned by Play Friends or its licensors, unless otherwise stated. You may not copy, modify, distribute, sell, lease, reverse engineer, or otherwise use Play Friends Content without prior written authorization from Play Friends or the relevant rights holder.\n\n'
                'You acknowledge that Play Friends may generate revenue, goodwill, or other value from your use of the Services, including through paid Services, virtual items, value-added services, and other commercial activities. Except as expressly permitted by Play Friends in writing, you have no right to share in such revenue, goodwill, or value.\n\n'
                'You further acknowledge that you have no right to receive income or other consideration from User Content or from your use of music, sound recordings, audiovisual clips, virtual items, or other elements made available through the Services, unless expressly permitted by Play Friends in writing.\n\n'
                'Subject to your compliance with these Terms, Play Friends grants you a limited, non-exclusive, non-transferable, non-sublicensable, revocable license to access and use the Services and Play Friends Content solely for your personal, non-commercial use. Play Friends reserves all rights not expressly granted under these Terms.\n\n'
                'Play Friends may terminate this license at any time if you violate these Terms or if Play Friends otherwise determines that termination is necessary for legal, security, operational, or business reasons.\n\n'
                'You understand that content made available through the Services is provided for general information and entertainment purposes. Play Friends does not guarantee that any Play Friends Content or User Content is accurate, complete, reliable, or up to date.\n\n'
                'Play Friends has no obligation to pre-screen, monitor, review, or edit content posted or transmitted by users, although Play Friends may do so at its discretion and may remove or restrict content that violates these Terms, community standards, or applicable laws.',
              ),

              const SizedBox(height: 10),
              _buildSubSectionTitle('7.2 User-Generated Content'),
              _buildParagraph(
                'Users may be permitted to upload, post, stream, transmit, or otherwise make available content through the Services, including text, photos, videos, audio, sound recordings, musical works, comments, profile content, and other materials ("User Content").\n\n'
                'Users may also use features provided by Play Friends, including graphics, stickers, virtual items, filters, effects, and other elements ("Play Friends Elements"), to create or transmit User Content through the Services.\n\n'
                'User Content, including User Content containing Play Friends Elements, has not necessarily been verified or approved by Play Friends. Views expressed by users do not represent the views, opinions, or values of Play Friends.\n\n'
                'You must not submit User Content that you consider confidential or proprietary. Any User Content you submit through the Services will be treated as non-confidential and non-proprietary.\n\n'
                'By submitting User Content, you represent and warrant that you own the User Content or have obtained all necessary rights, licenses, permissions, and clearances to submit, transmit, display, use, and authorize use of such User Content through the Services.\n\n'
                'You retain ownership of any rights you hold in your User Content. However, by submitting User Content through the Services, you grant Play Friends a worldwide, non-exclusive, royalty-free, transferable, sublicensable, perpetual, and irrevocable license to use, reproduce, modify, adapt, publish, translate, distribute, display, perform, transmit, and create derivative works from your User Content in any format or media, whether now known or developed in the future, for purposes related to operating, improving, promoting, and providing the Services.',
              ),

              const SizedBox(height: 16),
              _buildSectionTitle('8. Prohibited User Content and Behavior'),
              _buildParagraph(
                'You must not upload, post, transmit, distribute, or otherwise make available any User Content or engage in any behavior that violates these Terms, applicable laws, or the rights of others. Prohibited conduct includes, without limitation:\n\n'
                '• Illegal Content: You must not post or transmit content that is illegal, promotes illegal activity, or violates applicable laws or regulations.\n\n'
                '• Harmful or Offensive Content: You must not upload or transmit content that is abusive, harassing, defamatory, threatening, hateful, discriminatory, sexually exploitative, violent, or otherwise harmful to other users.\n\n'
                '• Infringement of Intellectual Property: You must not upload or transmit content that infringes copyrights, trademarks, privacy rights, publicity rights, or other rights of any person or entity, unless you have the right to do so.\n\n'
                '• Spamming or Fraudulent Behavior: You must not engage in spam, phishing, scams, deceptive promotions, unauthorized advertising, financial fraud, or other misleading conduct.\n\n'
                '• Malicious Software: You must not upload, transmit, or distribute viruses, malware, spyware, or other harmful code that may damage, disrupt, or interfere with the Services or other users\' devices.\n\n'
                '• Impersonation or False Information: You must not impersonate other users, streamers, Play Friends employees, or any other person or entity, or provide false or misleading information about yourself or others.\n\n'
                'If you believe another user has posted content or engaged in behavior that violates these Terms, you may report it through the Play Friends App Feedback section in Settings or by contacting us at playgamefriendes@gmail.com. We may ask you to provide information to verify the report before taking action.\n\n'
                'Play Friends reserves the right to remove content, restrict visibility, suspend accounts, terminate accounts, or take other appropriate action against users who violate these Terms or applicable laws.',
              ),

              const SizedBox(height: 16),
              _buildSectionTitle('9. Prohibition of CSAE'),
              _buildParagraph(
                'Play Friends strictly prohibits any form of Child Sexual Abuse Material (CSAE), child exploitation, or conduct involving the sexual abuse or exploitation of minors. Users must not upload, distribute, solicit, promote, or engage with any content involving CSAE or child exploitation in any form, including images, videos, text, audio, links, or other media.\n\n'
                'Play Friends is committed to protecting minors and maintaining a safe online environment. If Play Friends becomes aware of suspected CSAE or child exploitation, Play Friends may remove the content immediately, suspend or terminate relevant accounts, preserve relevant information where required, and cooperate with law enforcement or regulatory authorities.\n\n'
                'Play Friends may use technical tools, manual review, user reporting, and other measures to detect, prevent, and respond to CSAE. Users are encouraged to report any suspected inappropriate or illegal content through the App or by contacting Play Friends.\n\n'
                'Possession, distribution, solicitation, or creation of CSAE is a serious criminal offense in many jurisdictions. Play Friends does not tolerate any behavior that threatens the safety, dignity, or rights of children.',
              ),

              const SizedBox(height: 16),
              _buildSectionTitle('10. Other Terms'),
              _buildParagraph(
                '10.1 This Agreement constitutes the entire agreement between you and Play Friends regarding your use of the Services, unless additional written terms apply to specific features or services.\n\n'
                '10.2 If any provision of this Agreement is found to be invalid, illegal, or unenforceable by a competent authority, the remaining provisions will continue to be valid and enforceable to the fullest extent permitted by law.\n\n'
                '10.3 The headings in this Agreement are provided for convenience only and do not affect the interpretation of the Agreement.',
              ),

              const SizedBox(height: 16),
              _buildSectionTitle('11. Contact Us'),
              _buildParagraph(
                'If you have any questions, concerns, or feedback regarding this Agreement, the Services, or any other aspect of the App, please contact us through the following details:',
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
                      color: AppColors.primaryBlueLight.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.mail_rounded,
                          color: AppColors.primaryBlueLight, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Email Support',
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
                          color: AppColors.primaryBlueLight, size: 18),
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
