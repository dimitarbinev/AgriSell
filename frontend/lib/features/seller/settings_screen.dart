import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../shared/providers/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = (ref.watch(themeModeProvider).value ?? ThemeMode.dark) == ThemeMode.dark;
    final notificationsOn = ref.watch(notificationsEnabledProvider).value ?? true;
    final colorScheme = Theme.of(context).colorScheme;
    final textPrimaryColor = colorScheme.onSurface;
    final textSecondaryColor = colorScheme.onSurface.withValues(alpha: 0.6);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Appearance ───
          _SectionHeader(title: 'Appearance', textColor: textSecondaryColor),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            iconColor: isDark ? const Color(0xFF9575CD) : const Color(0xFFFFA726),
            title: 'Dark Mode',
            subtitle: isDark ? 'Switch to light theme' : 'Switch to dark theme',
            trailing: Switch.adaptive(
              value: isDark,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
              activeColor: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 24),

          // ─── Notifications ───
          _SectionHeader(title: 'Notifications', textColor: textSecondaryColor),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: notificationsOn ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
            iconColor: notificationsOn ? AppTheme.accentGreen : AppTheme.textTertiary,
            title: 'Push Notifications',
            subtitle: notificationsOn ? 'You will receive notifications' : 'Notifications are disabled',
            trailing: Switch.adaptive(
              value: notificationsOn,
              onChanged: (_) => ref.read(notificationsEnabledProvider.notifier).toggle(),
              activeColor: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 24),

          // ─── About ───
          _SectionHeader(title: 'About', textColor: textSecondaryColor),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.privacy_tip_rounded,
            iconColor: const Color(0xFF42A5F5),
            title: 'Privacy Policy',
            subtitle: 'How we handle your data',
            trailing: Icon(Icons.chevron_right, color: textSecondaryColor),
            onTap: () => _showPolicyDialog(context, _PolicyType.privacy),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.gavel_rounded,
            iconColor: const Color(0xFF26A69A),
            title: 'Terms of Service',
            subtitle: 'Rules and agreements',
            trailing: Icon(Icons.chevron_right, color: textSecondaryColor),
            onTap: () => _showPolicyDialog(context, _PolicyType.terms),
          ),
          const SizedBox(height: 24),

          // ─── App Info ───
          Center(
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                  ),
                  child: const Icon(Icons.eco, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 10),
                Text(
                  'Agro Street Market',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showPolicyDialog(BuildContext context, _PolicyType type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == _PolicyType.privacy ? 'Privacy Policy' : 'Terms of Service'),
        content: SingleChildScrollView(
          child: Text(
            type == _PolicyType.privacy ? _privacyPolicyText : _termsOfServiceText,
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

enum _PolicyType { privacy, terms }

// ─── Privacy Policy Content ───
const _privacyPolicyText = '''
Last updated: March 2026

At Agro Street Market, we take your privacy seriously. This policy explains how we collect, use, and protect your personal information.

1. Information We Collect
We collect information you provide directly, such as your name, email address, phone number, and agricultural product data when you register or use our services.

2. How We Use Your Information
Your information is used to:
• Operate and improve the platform
• Connect buyers and sellers
• Send order updates and notifications
• Comply with legal obligations

3. Data Sharing
We do not sell your personal data. We may share it with trusted service providers who help us operate the platform, such as payment processors and cloud infrastructure providers.

4. Data Security
We use industry-standard encryption and security measures to protect your data. However, no system is 100% secure, and we cannot guarantee absolute security.

5. Your Rights
You have the right to access, correct, or delete your personal data. Contact us at privacy@agrostreetmarket.com to exercise these rights.

6. Cookies
Our app may use local storage to remember your preferences (e.g., dark mode, notification settings).

7. Changes to This Policy
We may update this policy from time to time. We will notify you of significant changes through the app.

If you have questions, please contact us at privacy@agrostreetmarket.com.
''';

// ─── Terms of Service Content ───
const _termsOfServiceText = '''
Last updated: March 2026

Welcome to Agro Street Market. By using our platform, you agree to these Terms of Service.

1. Acceptance of Terms
By accessing or using Agro Street Market, you agree to be bound by these terms. If you do not agree, please do not use the service.

2. Eligibility
You must be at least 18 years old to use this platform. By registering, you represent that you meet this requirement.

3. Seller Responsibilities
Sellers are responsible for the accuracy of all listings, including product descriptions, quantities, prices, and availability. Misrepresentation is grounds for account suspension.

4. Buyer Responsibilities
Buyers agree to honour confirmed reservations. Repeated cancellations may result in account restrictions.

5. Prohibited Conduct
Users may not:
• Post false or misleading information
• Use the platform for illegal activities
• Harass or abuse other users
• Attempt to circumvent platform security

6. Payments and Transactions
All financial transactions happen directly between buyers and sellers. Agro Street Market is not responsible for disputes arising from individual transactions.

7. Intellectual Property
All content and trademarks on this platform are owned by Agro Street Market unless otherwise stated.

8. Limitation of Liability
To the fullest extent permitted by law, Agro Street Market is not liable for indirect, incidental, or consequential damages arising from your use of the service.

9. Termination
We reserve the right to terminate or suspend accounts that violate these terms without notice.

10. Governing Law
These terms are governed by the laws of Bulgaria.

For questions, contact us at legal@agrostreetmarket.com.
''';

// ─── Helper Widgets ───
class _SectionHeader extends StatelessWidget {
  final String title;
  final Color textColor;
  const _SectionHeader({required this.title, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          color: colorScheme.surface,
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
