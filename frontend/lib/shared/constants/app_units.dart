class AppUnits {
  static const List<String> all = [
    'PCS', 'KG', 'GM', 'LTR', 'ML', 'MTR', 'CM', 'FT', 'IN',
    'BOX', 'PKT', 'SET', 'PAIR', 'DOZ', 'ROLL', 'BAG', 'BTL', 'CAN', 'CTN', 'TBS',
  ];

  static const Map<String, String> labels = {
    'PCS': 'Pieces',
    'KG': 'Kilograms',
    'GM': 'Grams',
    'LTR': 'Litres',
    'ML': 'Millilitres',
    'MTR': 'Metres',
    'CM': 'Centimetres',
    'FT': 'Feet',
    'IN': 'Inches',
    'BOX': 'Boxes',
    'PKT': 'Packets',
    'SET': 'Sets',
    'PAIR': 'Pairs',
    'DOZ': 'Dozens',
    'ROLL': 'Rolls',
    'BAG': 'Bags',
    'BTL': 'Bottles',
    'CAN': 'Cans',
    'CTN': 'Cartons',
    'TBS': 'Tablets',
  };

  static String label(String code) => labels[code] ?? code;
}
