import 'package:flutter/material.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

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
            const Center(child: Text('Terms and Conditions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30))),
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

            sectionHeading("\n1. Acceptance of Terms"),
            sectionText("By downloading, installing, accessing, or using the Compassionate Caregivers Training mobile application (\"App\"), you (\"User,\" \"you,\" or \"your\") agree to be legally bound by these Terms and Conditions (\"Terms\"). These Terms constitute a binding agreement between you and Compassionate Caregivers Home Care (\"Company,\" \"we,\" \"our,\" or \"us\").\n\nIf you do not agree to all terms and conditions of this agreement, you may not access or use the App."),
            sectionHeading("\n2. App Description"),
            sectionTitle("2.1 Purpose"),
            sectionText("The Compassionate Caregivers Training App is an educational platform designed to provide training, assessment, and competency management for caregiver professionals employed by or contracted with Compassionate Caregivers Home Care."),

            sectionTitle("2.2 Features"),
            sectionText("• Video-based training modules and educational content \n• Skills assessments and competency examinations \n• Progress tracking and certification management \n• Administrative tools for content management and user oversight"),

            sectionTitle("2.3 User Classifications"),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 15,
                    color: AppUtils.getColorScheme(context).onSurface, // Set this to your desired text color
                  ),
                  children: const [
                    TextSpan(
                      text: 'Tier 1 - Administrators: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: 'Full system access, user management, content creation and assignment\n',
                    ),
                    TextSpan(
                      text: 'Tier 2 - Nurses: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: 'Content creation, category management, caregiver supervision\n',
                    ),
                    TextSpan(
                      text: 'Tier 3 - Caregivers: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: 'Content consumption, training completion, assessment participation',
                    ),
                  ],
                ),
              ),
            ),

            sectionHeading("\n3. Eligibility and Account Requirements"),
            sectionTitle("3.1 User Eligibility"),
            sectionText("To use this App, you must: \n\n• Be at least 18 years of age \n• Be an employee, contractor, or authorized representative of Compassionate Caregivers Home Care \n• Have received proper authorization and access credentials \n• Maintain current professional credentials as required by your position"),

            sectionTitle("3.2 Account Security"),
            sectionText("\n• You are solely responsible for maintaining the confidentiality of your login credentials \n• You must immediately notify us of any suspected unauthorized use of your account \n• You are liable for all activities conducted under your account \n• Sharing account credentials is strictly prohibited"),

            sectionTitle("3.3 Account Accuracy"),
            sectionText("You agree to provide accurate, current, and complete information during registration and to update such information as necessary to maintain its accuracy."),

            sectionHeading("\n4. Permitted Uses"),
            sectionTitle("4.1 Authorized Activities"),
            sectionText("You may use the App to:\n\n• Access assigned training materials and educational resources \n• Complete required training modules and continuing education requirements \n• Participate in competency assessments and skill evaluations \n• Track your professional development and certification status \n• Communicate with supervisors regarding training requirements"),

            sectionTitle("4.2 Professional Standards"),
            sectionText("All App usage must:\n\n• Comply with professional caregiver standards and ethics \n• Adhere to company policies and procedures \n• Respect patient privacy and confidentiality requirements \n• Support quality improvement and patient safety initiatives"),

            sectionHeading("\n5. Prohibited Uses"),
            sectionText("You expressly agree NOT to:\n\n• Use the App for any unlawful purpose or in violation of these Terms \n• Share, distribute, or republish training content outside the App \n• Attempt to gain unauthorized access to any part of the App or its systems \n• Interfere with or disrupt the App's functionality or other users' access \n• Upload malicious software, viruses, or harmful code \n• Use the App for personal, commercial, or non-work-related purposes \n• Circumvent any security measures or access controls \n• Violate any applicable laws, regulations, or professional standards"),

            sectionHeading("\n6. Content and Intellectual Property"),
            sectionTitle("6.1 Proprietary Rights"),
            sectionText("All content within the App, including but not limited to text, graphics, videos, audio, software, and training materials, is the exclusive property of Compassionate Caregivers Home Care or its licensors and is protected by copyright, trademark, and other intellectual property laws."),

            sectionTitle("6.2 Limited License"),
            sectionText("Subject to these Terms, we grant you a limited, non-exclusive, non-transferable, revocable license to access and use the App solely for authorized professional purposes."),

            sectionTitle("6.3 User-Generated Content"),
            sectionText("Any content you upload, submit, or create within the App:\n\n• Must be accurate, appropriate, and relevant to caregiver training \n• Must not violate any third-party rights or applicable laws \n• Grants us a license to use such content for training and educational purposes \n• Remains subject to our content standards and review"),

            sectionTitle("6.4 Third-Party Content"),
            sectionText("The App may include content from third parties, including YouTube videos and external resources. Such content remains the property of its respective owners and is subject to their terms of use."),

            sectionHeading("\n7. Training and Compliance"),
            sectionTitle("7.1 Training Requirements"),
            sectionText("• Completion of assigned training modules may be mandatory for continued employment \n• Training deadlines and requirements are established by management\n• Failure to meet training requirements may result in employment consequences\n• Additional training may be required based on performance assessments"),

            sectionTitle("7.2 Assessment and Evaluation"),
            sectionText("• All assessments and examinations are monitored and recorded\n• Results may be used for competency evaluation and employment decisions\n• Cheating or fraudulent activity during assessments is strictly prohibited\n• Assessment retakes may be allowed at management discretion"),

            sectionTitle("7.3 Certification and Records"),
            sectionText("• Training completions and certifications are recorded for regulatory compliance\n• Records may be shared with regulatory bodies and licensing authorities\n• Certificates are for internal verification and may not guarantee external recognition\n• False certification claims may result in disciplinary action"),

            sectionHeading("\n8. Privacy and Monitoring"),
            sectionTitle("8.1 Data Collection"),
            sectionText("We collect and monitor various types of information as detailed in our Privacy Policy, including training progress, assessment results, and App usage patterns."),

            sectionTitle("8.2 Monitoring and Surveillance"),
            sectionText("• App usage is continuously monitored for compliance and security purposes \n• Training activities, assessment performance, and progress are tracked and reported\n• Supervisors and administrators have access to your training records and performance data"),

            sectionTitle("8.3 Privacy Policy"),
            sectionText("Your privacy is governed by our Privacy Policy, which is incorporated into these Terms by reference."),

            sectionHeading("\n9. Technology and System Requirements"),
            sectionTitle("9.1 Technical Requirements"),
            sectionText("• Compatible mobile device with sufficient processing power and storage \n• Stable internet connection for content access and synchronization\n• Current operating system and security updates\n• Compliance with company-approved device policies"),

            sectionTitle("9.2 Technical Support"),
            sectionText("• Support is provided during standard business hours\n• Users are responsible for device maintenance and software updates\n• We reserve the right to discontinue support for outdated or incompatible devices"),

            sectionHeading("\n10. Service Availability and Modifications"),
            sectionTitle("10.1 Service Availability"),
            sectionText("• We strive to maintain continuous App availability but cannot guarantee uninterrupted service\n• Scheduled maintenance may temporarily restrict access\n• Emergency maintenance may occur without advance notice"),

            sectionTitle("10.2 Modifications and Updates"),
            sectionText("We reserve the right to: \n• Modify, update, or discontinue App features at any time\n• Change training content, assessments, and requirements\n• Update system requirements and compatibility standards\n• Implement new policies and procedures"),

            sectionHeading("\n11. Limitation of Liability and Disclaimers"),
            sectionTitle("11.1 Disclaimers"),
            sectionText("THE APP IS PROVIDED \"AS IS\" AND \"AS AVAILABLE\" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT."),

            sectionTitle("11.2 Limitation of Liability"),
            sectionText("TO THE MAXIMUM EXTENT PERMITTED BY LAW, COMPASSIONATE CAREGIVERS HOME CARE SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING BUT NOT LIMITED TO LOSS OF PROFITS, DATA, OR USE, ARISING OUT OF OR RELATING TO YOUR USE OF THE APP."),

            sectionTitle("11.3 Maximum Liability"),
            sectionText("Our total liability for any claims arising under these Terms shall not exceed the amount paid by you, if any, for accessing the App during the twelve (12) months preceding the claim."),

            sectionHeading("\n12. Indemnification"),
            sectionText("You agree to indemnify, defend, and hold harmless Compassionate Caregivers Home Care, its officers, directors, employees, and agents from and against any and all claims, damages, obligations, losses, liabilities, costs, and expenses arising from: \n\n• Your use of the App \n• Your violation of these Terms\n• Your violation of any third-party rights\n• Any false or misleading information you provide"),

            sectionHeading("\n13. Employment Relationship"),
            sectionTitle("13.1 No Modification of Employment"),
            sectionText("These Terms do not modify, alter, or supersede your employment agreement or company policies. Your employment relationship remains governed by applicable employment contracts and company handbook provisions."),

            sectionTitle("13.2 Disciplinary Measures"),
            sectionText("Violations of these Terms may result in: \n\n• Temporary or permanent suspension of App access\n• Mandatory additional training requirements\n• Disciplinary action up to and including termination of employment\n• Legal action for damages or injunctive relief"),

            sectionHeading("\n14. Termination"),
            sectionTitle("14.1 Termination by Company"),
            sectionText("We may terminate or suspend your access to the App immediately, without prior notice or liability, for any reason, including but not limited to:\n\n• Breach of these Terms\n• Termination of employment or contractor relationship\n• Violation of company policies or professional standards\n• Security concerns or legal requirements"),

            sectionTitle("14.2 Effect of Termination"),
            sectionText("Upon termination:\n\n• Your access to the App will be immediately revoked \n• All rights granted under these Terms will cease\n• Training records will be retained according to company policy\n• Certain provisions of these Terms will survive termination"),

            sectionHeading("\n15. Governing Law and Dispute Resolution"),
            sectionTitle("15.1 Governing Law"),
            sectionText("These Terms are governed by and construed in accordance with the laws of the State of Ohio, without regard to conflict of law principles."),

            sectionTitle("15.2 Jurisdiction"),
            sectionText("Any disputes arising under these Terms shall be subject to the exclusive jurisdiction of the state and federal courts located in Ohio."),

            sectionTitle("15.3 Dispute Resolution"),
            sectionText("• Internal disputes should first be addressed through company HR procedures \n• Legal disputes may be subject to mandatory arbitration if required by employment agreement\n• Both parties waive the right to jury trial for disputes arising under these Terms"),

            sectionHeading("\n16. General Provisions"),
            sectionTitle("16.1 Entire Agreement"),
            sectionText("These Terms, together with our Privacy Policy, constitute the entire agreement between you and Compassionate Caregivers Home Care regarding the App."),

            sectionTitle("16.2 Severability"),
            sectionText("If any provision of these Terms is deemed invalid or unenforceable, the remaining provisions will remain in full force and effect."),

            sectionTitle("16.3 Waiver"),
            sectionText("No waiver of any term or condition shall be deemed a further or continuing waiver of such term or any other term."),

            sectionTitle("16.4 Assignment"),
            sectionText("You may not assign your rights under these Terms without our prior written consent. We may assign our rights without restriction."),

            sectionHeading("\n17. Updates to Terms"),
            sectionTitle("17.1 Modification Rights"),
            sectionText("We reserve the right to modify these Terms at any time. Changes will be effective immediately upon posting of the revised Terms within the App."),

            sectionTitle("17.2 Notification"),
            sectionText("• Material changes will be communicated through in-app notifications\n• Continued use of the App constitutes acceptance of updated Terms\n• You are responsible for regularly reviewing these Terms"),

            sectionHeading("\n18. Contact Information"),
            sectionText("For questions, concerns, or notices regarding these Terms:"),
            sectionTitle("Legal Department:"),
            sectionText("Compassionate Caregivers Home Care \n5050 Blazer Pkwy # 100\nDublin, OH 43017\nEmail: info@ccgrhc.com\nPhone: +1 614-710-0078"),
            sectionTitle("Technical Support:"),
            sectionText("Email: info@ccgrhc.com\nPhone: +1 614-710-0078\nBusiness Hours: Monday - Friday, 8:00 AM - 5:00 PM EST"),

            sectionHeading("\n19. Acknowledgment"),
            sectionText("BY USING THE APP, YOU ACKNOWLEDGE THAT YOU HAVE READ, UNDERSTOOD, AND AGREE TO BE BOUND BY THESE TERMS AND CONDITIONS."),
            sectionText("\nThese Terms and Conditions are effective as of July 1, 2025, and govern all use of the Compassionate Caregivers Training App."),

            const SizedBox(height: 70)
          ],
        ),
      ),
    );
  }
}