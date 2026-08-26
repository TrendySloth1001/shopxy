class LegalBlock {
  const LegalBlock.p(this.paragraph) : bullets = null;
  const LegalBlock.ul(this.bullets) : paragraph = null;
  final String? paragraph;
  final List<String>? bullets;
}

class LegalSection {
  const LegalSection(this.heading, this.blocks);
  final String heading;
  final List<LegalBlock> blocks;
}

const String kLegalUpdated = 'Last updated June 2026';

const List<LegalSection> kPrivacySections = <LegalSection>[
  LegalSection('Overview', <LegalBlock>[
    LegalBlock.p('ShopXY (“we”, “us”) helps merchants run their shop — inventory, invoices, parties and payments. This policy explains what personal data we collect, why, how long we keep it, and your rights under India’s Digital Personal Data Protection Act, 2023 (DPDP).'),
  ]),
  LegalSection('What we collect', <LegalBlock>[
    LegalBlock.p('Account details (name, email, phone), shop details (name, address, GSTIN/PAN where you provide them), and the business records you create in the app (products, invoices, customers, vendors, payments). We also log basic technical data to keep the service secure and working.'),
  ]),
  LegalSection('How we use it', <LegalBlock>[
    LegalBlock.p('To provide the service, generate your invoices and reports, send transactional emails you opt into, and meet legal/tax obligations. We do not sell your personal data, and we do not use it for targeted advertising to children.'),
  ]),
  LegalSection('Who we share it with', <LegalBlock>[
    LegalBlock.p('We share data only with the processors who help us run ShopXY:'),
    LegalBlock.ul(<String>['Razorpay Software Private Limited — payment collection, refunds and payouts. Payment KYC details you submit for payouts are forwarded to Razorpay under their terms and are not stored by us.', 'Cloud hosting and infrastructure provider — application hosting, database, object storage and backups. [TO FILL: name the hosting provider, e.g. AWS Mumbai / specific vendor]']),
    LegalBlock.p('We also disclose data where required by law. We do not sell your personal data.'),
  ]),
  LegalSection('Retention schedule', <LegalBlock>[
    LegalBlock.p('We keep data only as long as we need it:'),
    LegalBlock.ul(<String>['Invoices, payments and tax records — retained for 8 years, the period required under Indian tax and company law.', 'Account and shop profile — kept while your account is active; deleted (or anonymised) within 90 days of account deletion, except records we must legally retain.', 'Support tickets and grievance records — up to 3 years from resolution.', 'Technical and security logs — up to 180 days.']),
  ]),
  LegalSection('Your rights under the DPDP Act', <LegalBlock>[
    LegalBlock.p('You can access, correct, export or delete your personal data from Settings → Data & privacy, subject to records we must legally retain. Export and deletion requests are honoured by our systems. You may also withdraw consent and nominate another person to exercise your rights in the event of death or incapacity. Contact our Grievance Officer for any request you can’t complete in-app.'),
  ]),
  LegalSection('Deleting your account and data', <LegalBlock>[
    LegalBlock.p('You can permanently delete your ShopXY account and the personal data tied to it at any time — you do not need to contact us first:'),
    LegalBlock.ul(<String>['In the app — go to Settings → Data & privacy → Delete account (the same path on the web app, Android and iOS). You’ll confirm with your password, then the account and every session are erased.', 'By email — if you can’t sign in, write to privacy@shopxy.app from your registered address and we’ll verify and action the request.']),
    LegalBlock.p('What is deleted: your profile, login credentials, shop settings, contacts (parties/vendors) and the business records you created, together with any payout draft held on your device. Deletion completes within 90 days.'),
    LegalBlock.p('What we must keep: where you have issued invoices or taken payments, Indian tax and company law requires us to retain those financial records for up to 8 years. Those records are retained in a restricted, minimised form (and dissociated from your login) for that period only, then deleted. A shop owner whose invoices are still inside that window cannot self-delete in-app — email support@shopxy.app for a controlled wipe of everything outside the legal-retention set.'),
  ]),
  LegalSection('Children\'s data', <LegalBlock>[
    LegalBlock.p('ShopXY is a business tool intended for users aged 18 and over. We do not knowingly process the personal data of a child (a person under 18) without verifiable consent from a parent or lawful guardian, and we do not undertake tracking, behavioural monitoring, or targeted advertising directed at children. If we learn that we hold a child’s data without the required consent, we will delete it.'),
  ]),
  LegalSection('Cross-border transfers', <LegalBlock>[
    LegalBlock.p('Your personal data is primarily stored and processed on infrastructure located in India. Where a processor (such as a payment provider) operates outside India, any transfer is limited to that purpose and made only to countries not restricted by the Government of India under the DPDP Act, with contractual safeguards in place.'),
  ]),
  LegalSection('Security & breach notification', <LegalBlock>[
    LegalBlock.p('We protect data with encryption in transit and access controls, and we forward payment KYC to our payment provider rather than storing it. No system is perfectly secure. In the event of a personal-data breach, we will notify the Data Protection Board of India and affected users without undue delay and within the timelines prescribed under the DPDP Act and its rules. We encourage strong passwords and care with account access.'),
  ]),
  LegalSection('Grievance Officer', <LegalBlock>[
    LegalBlock.p('In line with the Information Technology (Intermediary Guidelines) Rules, 2021 and India’s Digital Personal Data Protection Act, 2023, you may contact our Grievance Officer with any complaint about the service or your personal data:'),
    LegalBlock.ul(<String>['Name: [TO FILL: Grievance Officer name]', 'Designation: [TO FILL: designation]', 'Email: grievance@shopxy.app', 'Phone: [TO FILL: phone number]', 'Postal address: [TO FILL: registered postal address]']),
    LegalBlock.p('We acknowledge every grievance within 48 hours of receipt and aim to resolve grievances within one month. Grievances relating to your personal data under the DPDP Act are addressed within 15 days.'),
  ]),
  LegalSection('Contact', <LegalBlock>[
    LegalBlock.p('For privacy questions, email privacy@shopxy.app.'),
  ]),
];

const List<LegalSection> kTermsSections = <LegalSection>[
  LegalSection('Acceptance', <LegalBlock>[
    LegalBlock.p('By creating a ShopXY account you agree to these terms. If you use ShopXY on behalf of a business, you confirm you’re authorised to bind that business.'),
  ]),
  LegalSection('Your account', <LegalBlock>[
    LegalBlock.p('Keep your login secure and your shop details accurate. You’re responsible for activity under your account and for any team members you invite.'),
  ]),
  LegalSection('Acceptable use', <LegalBlock>[
    LegalBlock.p('Don’t use ShopXY for unlawful goods or activity, to infringe others’ rights, or to disrupt the service. You’re responsible for the legality of your listings, invoices and tax handling.'),
  ]),
  LegalSection('Your content & records', <LegalBlock>[
    LegalBlock.p('You own the business data you put into ShopXY. You grant us the limited rights needed to host and process it to run the service. You’re responsible for keeping your own backups of critical records.'),
  ]),
  LegalSection('Payments & payouts', <LegalBlock>[
    LegalBlock.p('Where you enable payouts, settlement and KYC are handled by our payment partner under their terms. Taxes (e.g. GST) on your sales are your responsibility.'),
  ]),
  LegalSection('Availability & liability', <LegalBlock>[
    LegalBlock.p('ShopXY is provided “as is”. To the extent permitted by law, we aren’t liable for indirect or consequential losses. We aim for high availability but don’t guarantee uninterrupted service.'),
  ]),
  LegalSection('Termination', <LegalBlock>[
    LegalBlock.p('You can stop using ShopXY at any time and delete your account from Settings. We may suspend accounts that violate these terms.'),
  ]),
  LegalSection('Governing law', <LegalBlock>[
    LegalBlock.p('These terms are governed by the laws of India. Questions? Email support@shopxy.app.'),
  ]),
  LegalSection('Grievance Officer', <LegalBlock>[
    LegalBlock.p('In line with the Information Technology (Intermediary Guidelines) Rules, 2021 and India’s Digital Personal Data Protection Act, 2023, you may contact our Grievance Officer with any complaint about the service or your personal data:'),
    LegalBlock.ul(<String>['Name: [TO FILL: Grievance Officer name]', 'Designation: [TO FILL: designation]', 'Email: grievance@shopxy.app', 'Phone: [TO FILL: phone number]', 'Postal address: [TO FILL: registered postal address]']),
    LegalBlock.p('We acknowledge every grievance within 48 hours of receipt and aim to resolve grievances within one month. Grievances relating to your personal data under the DPDP Act are addressed within 15 days.'),
  ]),
];
