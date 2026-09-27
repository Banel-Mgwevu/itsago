/// Reference data for the onboarding profile-setup flow.
/// Institution lists last verified against DHET-referenced sources.

enum InstitutionType { university, tvet, private_ }

class Institution {
  final String name;
  final InstitutionType type;
  const Institution(this.name, this.type);
}

class SAData {
  SAData._();

  static const List<String> provinces = [
    'Eastern Cape', 'Free State', 'Gauteng', 'KwaZulu-Natal', 'Limpopo',
    'Mpumalanga', 'Northern Cape', 'North West', 'Western Cape',
  ];

  static const List<String> employmentStatuses = [
    'Unemployed & job-seeking',
    'Employed & looking to switch',
    'Student',
    'Self-employed / informal work',
  ];

  static const List<String> educationLevels = [
    'Below Grade 12',
    'Matric (Grade 12)',
    'Certificate',
    'Diploma',
    'Degree',
    'Postgraduate',
  ];

  /// Education levels that unlock the Institution + Field of Study step.
  static const List<String> higherEducationLevels = [
    'Diploma', 'Degree', 'Postgraduate',
  ];

  static const List<String> targetIndustries = [
    'Information Technology', 'Finance & Banking', 'Retail & Sales',
    'Healthcare', 'Education', 'Hospitality & Tourism', 'Government & Public Sector',
    'Manufacturing', 'Engineering', 'Construction', 'Marketing & Media',
    'Logistics & Supply Chain', 'Legal', 'Agriculture', 'Other',
  ];

  static const List<String> careerGoals = [
    'Entry-level job', 'Internship / learnership', 'Permanent role', 'Career change',
  ];

  // Age buckets rather than an exact number - enough for personalisation
  // (e.g. graduate vs. career-changer messaging) without asking for
  // something as precise/sensitive as an exact birthdate.
  static const List<String> ageRanges = [
    'Below 18', '18–24', '25–34', '35–44', '45–54', '55+',
  ];

  // 26 public universities.
  static const List<Institution> universities = [
    Institution('University of Cape Town', InstitutionType.university),
    Institution('University of Fort Hare', InstitutionType.university),
    Institution('University of the Free State', InstitutionType.university),
    Institution('University of KwaZulu-Natal', InstitutionType.university),
    Institution('University of Limpopo', InstitutionType.university),
    Institution('North-West University', InstitutionType.university),
    Institution('University of Pretoria', InstitutionType.university),
    Institution('Rhodes University', InstitutionType.university),
    Institution('Stellenbosch University', InstitutionType.university),
    Institution('University of the Western Cape', InstitutionType.university),
    Institution('University of the Witwatersrand', InstitutionType.university),
    Institution('University of Johannesburg', InstitutionType.university),
    Institution('University of South Africa (UNISA)', InstitutionType.university),
    Institution('Nelson Mandela University', InstitutionType.university),
    Institution('University of Venda', InstitutionType.university),
    Institution('Walter Sisulu University', InstitutionType.university),
    Institution('University of Zululand', InstitutionType.university),
    Institution('Cape Peninsula University of Technology', InstitutionType.university),
    Institution('Central University of Technology', InstitutionType.university),
    Institution('Durban University of Technology', InstitutionType.university),
    Institution('Mangosuthu University of Technology', InstitutionType.university),
    Institution('Tshwane University of Technology', InstitutionType.university),
    Institution('Vaal University of Technology', InstitutionType.university),
    Institution('Sol Plaatje University', InstitutionType.university),
    Institution('University of Mpumalanga', InstitutionType.university),
    Institution('Sefako Makgatho Health Sciences University', InstitutionType.university),
  ];

  // All 50 public TVET colleges (DHET-registered), by province.
  static const List<Institution> tvetColleges = [
    // Gauteng
    Institution('Central Johannesburg TVET College', InstitutionType.tvet),
    Institution('Ekurhuleni East TVET College', InstitutionType.tvet),
    Institution('Ekurhuleni West TVET College', InstitutionType.tvet),
    Institution('Sedibeng TVET College', InstitutionType.tvet),
    Institution('South West Gauteng TVET College', InstitutionType.tvet),
    Institution('Tshwane North TVET College', InstitutionType.tvet),
    Institution('Tshwane South TVET College', InstitutionType.tvet),
    Institution('Western TVET College', InstitutionType.tvet),
    // Western Cape
    Institution('Boland TVET College', InstitutionType.tvet),
    Institution('College of Cape Town for TVET', InstitutionType.tvet),
    Institution('False Bay TVET College', InstitutionType.tvet),
    Institution('Northlink TVET College', InstitutionType.tvet),
    Institution('South Cape TVET College', InstitutionType.tvet),
    Institution('West Coast TVET College', InstitutionType.tvet),
    // KwaZulu-Natal
    Institution('Coastal TVET College', InstitutionType.tvet),
    Institution('Elangeni TVET College', InstitutionType.tvet),
    Institution('Esayidi TVET College', InstitutionType.tvet),
    Institution('Majuba TVET College', InstitutionType.tvet),
    Institution('Mnambithi TVET College', InstitutionType.tvet),
    Institution('Mthashana TVET College', InstitutionType.tvet),
    Institution('Thekwini TVET College', InstitutionType.tvet),
    Institution('Umfolozi TVET College', InstitutionType.tvet),
    Institution('Umgungundlovu TVET College', InstitutionType.tvet),
    // Eastern Cape
    Institution('Buffalo City TVET College', InstitutionType.tvet),
    Institution('Eastcape Midlands TVET College', InstitutionType.tvet),
    Institution('Ikhala TVET College', InstitutionType.tvet),
    Institution('Ingwe TVET College', InstitutionType.tvet),
    Institution('King Hintsa TVET College', InstitutionType.tvet),
    Institution('King Sabata Dalindyebo TVET College', InstitutionType.tvet),
    Institution('Lovedale TVET College', InstitutionType.tvet),
    Institution('Port Elizabeth TVET College', InstitutionType.tvet),
    // Limpopo
    Institution('Capricorn TVET College', InstitutionType.tvet),
    Institution('Lephalale TVET College', InstitutionType.tvet),
    Institution('Letaba TVET College', InstitutionType.tvet),
    Institution('Mopani South East TVET College', InstitutionType.tvet),
    Institution('Sekhukhune TVET College', InstitutionType.tvet),
    Institution('Vhembe TVET College', InstitutionType.tvet),
    Institution('Waterberg TVET College', InstitutionType.tvet),
    // Free State
    Institution('Flavius Mareka TVET College', InstitutionType.tvet),
    Institution('Goldfields TVET College', InstitutionType.tvet),
    Institution('Maluti TVET College', InstitutionType.tvet),
    Institution('Motheo TVET College', InstitutionType.tvet),
    // Mpumalanga
    Institution('Ehlanzeni TVET College', InstitutionType.tvet),
    Institution('Gert Sibande TVET College', InstitutionType.tvet),
    Institution('Nkangala TVET College', InstitutionType.tvet),
    // North West
    Institution('Orbit TVET College', InstitutionType.tvet),
    Institution('Taletso TVET College', InstitutionType.tvet),
    Institution('Vuselela TVET College', InstitutionType.tvet),
    // Northern Cape
    Institution('Northern Cape Rural TVET College', InstitutionType.tvet),
    Institution('Northern Cape Urban TVET College', InstitutionType.tvet),
  ];

  // Well-known DHET-registered private higher education institutions.
  // Not exhaustive - the picker always offers "Other" as a fallback
  // since new private colleges register and some close/rebrand.
  static const List<Institution> privateColleges = [
    Institution('Eduvos', InstitutionType.private_),
    Institution('Varsity College (IIE)', InstitutionType.private_),
    Institution('Rosebank College (IIE)', InstitutionType.private_),
    Institution('Vega School (IIE)', InstitutionType.private_),
    Institution('Damelin', InstitutionType.private_),
    Institution('Boston City Campus', InstitutionType.private_),
    Institution('CTU Training Solutions', InstitutionType.private_),
    Institution('Milpark Education', InstitutionType.private_),
    Institution('Richfield Graduate Institute', InstitutionType.private_),
    Institution('AFDA', InstitutionType.private_),
    Institution('Oxbridge Academy', InstitutionType.private_),
    Institution('Regent Business School', InstitutionType.private_),
    Institution('Other', InstitutionType.private_),
  ];

  static List<Institution> institutionsFor(InstitutionType type) {
    switch (type) {
      case InstitutionType.university: return universities;
      case InstitutionType.tvet:        return tvetColleges;
      case InstitutionType.private_:    return privateColleges;
    }
  }
}
