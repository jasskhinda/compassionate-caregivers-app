import 'package:flutter/material.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';

class PrivacyAndPolicyScreen extends StatelessWidget {
  const PrivacyAndPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppUtils.getColorScheme(context).surface,
      ),
      body: const TermsContent(),
    );
  }
}

class TermsContent extends StatelessWidget {
  const TermsContent({super.key});

  Widget sectionHeading(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget sectionSubTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget sectionText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: AppUtils.getScreenSize(context).width > 1000 ? AppUtils.getScreenSize(context).width * 0.45 : double.infinity,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Center(child: Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30))),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 17, color: AppUtils.getColorScheme(context).onSurface.withAlpha(150)),
                const SizedBox(width: 2),
                Text("Last Updated: July 1, 2025", style: TextStyle(color: AppUtils.getColorScheme(context).onSurface.withAlpha(150))),
              ],
            ),

            sectionTitle("Company Information"),
            sectionText("Compassionate Caregivers Home Care\n"
                "5050 Blazer Pkwy #100\n"
                "Dublin, OH 43017\n"
                "Phone: +1 614-710-0078\n"
                "Email: info@ccgrhc.com\n"
                "Website: https://compassionatecaregivershc.com/"),

            sectionHeading("\n1. Overview"),
            sectionText("This Privacy Policy describes how Compassionate Caregivers Home Care (\"Company,\" \"we,\" \"our,\" or \"us\") collects, uses, and protects information when you use our Compassionate Caregivers Training mobile application (\"App\"). This policy applies to all users of the App, including administrators, staff, and caregivers.\nBy using our App, you consent to the collection and use of information in accordance with this policy. If you do not agree with our policies and practices, do not download, register with, or use this App."),

            sectionHeading("\n2. Information We Collect"),
            sectionTitle("2.1 Personal Information"),
            sectionText("We collect the following types of personal information:"),
            sectionSubTitle("Account Information:"),
            sectionText("• Full name and employee identification number\n• Email address and phone number\n• Job title and department\n• Professional credentials and certifications\n• Employment start date"),

            sectionSubTitle("Authentication Data:"),
            sectionText("• Login credentials (username and encrypted password)\n• Security questions and answers\n• Device identifiers for account security"),

            sectionTitle("2.2 Usage and Performance Data"),
            sectionSubTitle("Training Activity:"),
            sectionText("• Videos watched and viewing duration\n• Course completion status and timestamps\n• Quiz and examination scores\n• Learning path progress\n• Content interactions and preferences"),
            sectionSubTitle("App Analytics:"),
            sectionText("• Features accessed and frequency of use \n• Session duration and app performance metrics\n• Error logs and crash reports\n• Device information (operating system, version, model)"),

            sectionTitle("2.3 Content Data"),
            sectionSubTitle("Uploaded Content:"),
            sectionText("• Training videos uploaded by administrators and staff\n• Comments and feedback on training materials\n• Assessment responses and explanations"),

            sectionSubTitle("Assignment Data:"),
            sectionText("• Training assignments and deadlines\n• Competency requirements and completion status\n• Performance evaluations and improvement plans"),

            sectionHeading("\n3. How We Use Your Information"),
            sectionTitle("3.1 Primary Purposes"),
            sectionText("• Provide personalized training content and educational materials\n• Track learning progress and ensure compliance with training requirements\n• Conduct assessments and evaluate competency levels\n• Generate reports for supervisory and administrative purposes\n• Communicate training updates and requirements"),

            sectionTitle("3.2 Administrative Functions"),
            sectionText("• Manage user accounts and access permissions\n• Provide technical support and troubleshooting\n• Ensure app security and prevent unauthorized access\n• Comply with caregiver regulations and employment requirements\n• Improve app functionality and user experience"),

            sectionTitle("3.3 Legal and Regulatory Compliance"),
            sectionText("• Meet state and federal caregiver training requirements\n• Maintain records for regulatory audits and inspections\n• Support quality assurance and improvement initiatives\n• Fulfill employment law obligations"),

            sectionHeading("\n4. Information Sharing"),
            sectionTitle("4.1 Internal Sharing"),
            sectionText("Information may be shared within our organization with:\n• Direct supervisors and department managers\n• Human resources personnel\n• Training coordinators and administrators\n• Quality assurance and compliance teams\n• IT support sta (on a need-to-know basis)"),

            sectionTitle("4.2 Third-Party Service Providers"),
            sectionText("We may share information with trusted service providers who assist in:\n\n• Firebase Cloud hosting and data storage\n• App development and maintenance\n• Analytics and performance monitoring\n• Security services and monitoring\n\nAll third-party providers are contractually required to protect your information and use it only for the specified purposes."),

            sectionTitle("4.3 Legal Disclosures"),
            sectionText("We may disclose information when required by:\n• Court orders or legal processes\n• Government agencies and regulatory bodies\n• Law enforcement investigations\n• Healthcare licensing authorities\n• Emergency situations involving safety or security"),

            sectionTitle("4.4 No Sale of Personal Information"),
            sectionText("We do not sell, rent, lease, or otherwise transfer personal information to third parties for commercial purposes."),

            sectionHeading("\n5. Data Security"),
            sectionTitle("5.1 Security Measures"),
            sectionText("• We implement comprehensive security measures including:\n• Encryption of data in transit and at rest \n• Secure authentication and access controls\n• Regular security audits and vulnerability assessments\n• Employee training on data protection\n• Incident response and breach notification procedures"),

            sectionTitle("5.2 Access Controls"),
            sectionText("• Role-based permissions limiting access to authorized personnel \n• Multi-factor authentication for administrative accounts\n• Regular review and updating of user permissions\n• Audit logging of all data access and modifications"),

            sectionTitle("5.3 Data Backup and Recovery"),
            sectionText("• Regular automated backups of all data\n• Secure offsite storage of backup data\n• Tested disaster recovery procedures\n• Business continuity planning"),

            sectionHeading("\n6. Data Retention"),
            sectionTitle("6.1 Retention Periods"),
            sectionText("• Active Employee Records: Maintained during employment\n• Training Records: Retained for seven (7) years after completion\n• Assessment Results: Kept for five (5) years for compliance purposes\n• App Usage Logs: Retained for two (2) years\n• Security Logs: Maintained for three (3) years"),

            sectionTitle("6.2 Data Deletion"),
            sectionText("• Personal data is deleted within ninety (90) days of employment termination\n• Training records may be retained longer for regulatory compliance\n• Users may request deletion of non-essential personal information\n• Anonymized data may be retained indefinitely for research purposes"),

            sectionHeading("\n7. Your Rights"),
            sectionTitle("7.1 Access Rights"),
            sectionText("• View your personal information and training records\n• Obtain copies of your assessment results and certifications\n• Request information about how your data is used"),

            sectionTitle("7.2 Correction Rights"),
            sectionText("• Request correction of inaccurate or incomplete information\n• Update your contact information and preferences\n• Modify privacy settings where available"),

            sectionTitle("7.3 Portability Rights"),
            sectionText("• Request your training records in a portable format\n• Obtain certification documentation for external use\n• Transfer training completion data when permitted"),

            sectionTitle("7.4 Limitations"),
            sectionText("Certain information cannot be deleted or modified due to:\n• Legal and regulatory requirements\n• Employment record obligations\n• Ongoing investigations or disputes\n• System integrity and security needs"),

            sectionHeading("\n8. Third-Party Services"),
            sectionTitle("8.1 YouTube Integration"),
            sectionText("Our App integrates with YouTube for educational content delivery. YouTube's privacy policy and terms of service apply to their content and services."),

            sectionTitle("8.2 External Links"),
            sectionText("The App may contain links to external websites and services. We are not responsible for the privacy practices of these third parties."),

            sectionTitle("8.3 Mobile Platform"),
            sectionText("This App operates on mobile platforms (Android/iOS) subject to their respective privacy policies and terms of service."),

            sectionHeading("\n9. Children's Privacy"),
            sectionText("This App is intended exclusively for adult employees aged 18 and older. We do not knowingly collect information from minors under 18 years of age."),

            sectionHeading("\n10. International Users"),
            sectionText("This App is designed for use within the United States. Users accessing from other countries do so at their own risk and are responsible for compliance with local laws."),

            sectionHeading("\n11. Changes to This Policy"),
            sectionTitle("11.1 Policy Updates"),
            sectionText("We may update this Privacy Policy periodically to reflect changes in our practices, technology, or legal requirements."),

            sectionTitle("11.2 Notification of Changes"),
            sectionText("• Material changes will be communicated through in-app notifications\n• Email notifications to all registered users\n• Posted notice on our website\n• Updated effective date on this policy"),

            sectionTitle("11.3 Continued Use"),
            sectionText("Continued use of the App after changes constitutes acceptance of the updated policy."),

            sectionHeading("\n12. Contact Information"),
            sectionText("For questions, concerns, or requests regarding this Privacy Policy or your personal information:"),
            sectionSubTitle("Privacy Contact:"),
            sectionText("Compassionate Caregivers Home Care \n5050 Blazer Pkwy # 100\nDublin, OH 43017\nEmail: info@ccgrhc.com\nPhone: +1 614-710-0078"),
            sectionSubTitle("Privacy Contact:"),
            sectionText("Email: info@ccgrhc.com\nSubject: \"Privacy Request - [Your Name and Employee ID]\""),
            sectionText("We will respond to all privacy inquiries within thirty (30) days of receipt."),

            sectionHeading("\n13. Compliance Statement"),
            sectionText("This Privacy Policy complies with applicable federal and state privacy laws, including caregiver industry standards and employment privacy requirements. We are committed to protecting your privacy and maintaining the confidentiality of your personal information."),
            sectionText("This Privacy Policy is effective as of July 1, 2025, and governs all use of the Compassionate Caregivers Training App."),

            const SizedBox(height: 70)
          ],
        ),
      ),
    );
  }
}