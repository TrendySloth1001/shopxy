class Vendor {
  const Vendor({
    required this.id,
    required this.name,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.state,
    this.stateCode,
    this.pinCode,
    this.panNumber,
    this.gstin,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.transactionCount = 0,
    this.invoiceCount = 0,
  });

  final String id;
  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final String? state;
  final String? stateCode;
  final String? pinCode;
  final String? panNumber;
  final String? gstin;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int transactionCount;
  final int invoiceCount;
}
