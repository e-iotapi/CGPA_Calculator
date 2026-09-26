/// The minor programmes, as the Bulletin lists them (IV-129 to IV-141).
library;

/// One place in a minor: a course, or alternatives of which one counts.
typedef MinorSlot = List<String>;

/// A group of electives. [min] is how many of them the minor needs.
class MinorPool {
  const MinorPool(this.courses, {this.name, this.min = 0});
  final String? name;
  final int min;
  final List<MinorSlot> courses;
}

class Minor {
  const Minor({
    required this.name,
    required this.courses,
    required this.units,
    required this.core,
    required this.pools,
    this.electives = 2,
    this.projects = const {},
    this.notFor = const {},
  });

  /// "Data Science", without "Minor in".
  final String name;

  /// At least this many courses and units in all.
  final int courses;
  final int units;

  /// Every core course is required.
  final List<MinorSlot> core;
  final List<MinorPool> pools;

  /// At least this many electives across [pools].
  final int electives;

  /// Project or seminar courses; at most one may count.
  final Set<String> projects;

  /// Disciplines that may not take this minor.
  final Set<String> notFor;

  Iterable<MinorSlot> get electiveSlots => pools.expand((p) => p.courses);
}

/// A minor counts at most this many courses, and units, that are also
/// mandatory for the student's own degree.
const minorOverlapCourses = 2;
const minorOverlapUnits = 6;

/// The lowest GPA over a minor's courses that earns the certificate.
const minorMinGpa = 4.5;

MinorSlot _one(String id) => [id];
List<MinorSlot> _each(List<String> ids) => ids.map(_one).toList();

const _ds = [
  'BITS F453',
  'BITS F454',
  'BITS F459',
  'CS F317',
  'CS F407',
  'CS F415',
  'CS F425',
  'CS F426',
  'CS F429',
  'CS F432',
  'CS F433',
  'CS F434',
  'CS F437',
  'CS F469',
  'CS G519',
  'MATH F353',
  'MATH F424',
  'MATH F471',
];

final minors = <Minor>[
  Minor(
    name: 'Aeronautics',
    courses: 6,
    units: 18,
    core: _each(['AN F311', 'AN F312', 'AN F313']),
    pools: [
      MinorPool(
        _each([
          'AN F314',
          'AN F315',
          'ME F415',
          'ME F418',
          'ME F435',
          'ME F452',
          'ME F482',
          'ME F485',
          'EEE F242',
          'EEE F417',
          'ME F376',
        ]),
      ),
    ],
    projects: {'ME F376'},
  ),
  Minor(
    name: 'Biomedical Engineering',
    courses: 5,
    units: 15,
    core: _each(['BITS F418', 'PHA F214']),
    pools: [
      MinorPool(
        _each(['BIO F215', 'BITS F315', 'CHEM F414', 'MST F333', 'PHA F215']),
        name: 'Science pool',
        min: 1,
      ),
      MinorPool(
        [
          ..._each([
            'BITS F415',
            'BITS F417',
            'BITS F441',
            'BIO G532',
            'CS F320',
            'EEE F420',
            'EEE F435',
          ]),
          ['EEE F432', 'INSTR F432'],
          _one('ME F324'),
        ],
        name: 'Engineering pool',
        min: 2,
      ),
    ],
    electives: 3,
  ),
  Minor(
    name: 'Computational Economics',
    courses: 5,
    units: 15,
    core: _each(['ECON F215', 'ECON F241', 'ECON F242']),
    pools: [
      MinorPool(
        _each([
          'BITS F314',
          'BITS F464',
          'CS F320',
          'ECON F342',
          'ECON F419',
          'ECON F420',
          'MATH F424',
        ]),
      ),
    ],
  ),
  Minor(
    name: 'Computational Mechanics',
    courses: 5,
    units: 15,
    core: _each(['MATH F313', 'ME F427']),
    pools: [
      MinorPool([
        ..._each(['BITS F464', 'CS F422', 'MATH F425']),
        ['MATH F426', 'ME G512'],
        ..._each(['ME F321', 'ME F485', 'ME F430', 'ME G515']),
      ]),
    ],
  ),
  Minor(
    name: 'Computing and Intelligence',
    courses: 6,
    units: 18,
    core: _each(['BITS F232', 'CS F372', 'CS F407']),
    pools: [
      MinorPool(
        _each([
          'BITS F311',
          'BITS F452',
          'BITS F459',
          'BITS F463',
          'BITS F464',
          'CS F212',
          'CS F213',
          'CS F301',
          'CS F303',
          'CS F314',
          'CS F315',
          'CS F321',
          'CS F415',
          'CS F437',
          'IS F311',
          'IS F341',
        ]),
      ),
    ],
    notFor: {'A7'},
  ),
  Minor(
    name: 'Data Science',
    courses: 5,
    units: 15,
    core: _each(['BITS F464', 'CS F320', 'MATH F432']),
    pools: [
      MinorPool([
        ..._each(_ds),
        ['MATH F212', 'ME F320'],
      ]),
    ],
  ),
  Minor(
    name: 'Data Science in Climate and Health',
    courses: 6,
    units: 17,
    core: _each(['BITS F329', 'BITS F464', 'CS F320', 'MATH F432']),
    pools: [
      MinorPool(_each(['CE F326', 'CS F434', 'GS F212', 'MPH G510']), min: 2),
    ],
    projects: {'BITS F329'},
  ),
  Minor(
    name: 'English Studies',
    courses: 5,
    units: 15,
    core: _each(['GS F241', 'HSS F337']),
    pools: [
      MinorPool(
        _each([
          'GS F221',
          'GS F244',
          'GS F245',
          'HSS F222',
          'HSS F227',
          'HSS F228',
          'HSS F342',
        ]),
        name: 'Language',
      ),
      MinorPool(
        _each([
          'GS F242',
          'GS F322',
          'HSS F221',
          'HSS F226',
          'HSS F237',
          'HSS F316',
          'HSS F327',
          'HSS F330',
          'HSS F332',
          'HSS F335',
          'HSS F336',
          'HSS F338',
          'HSS F340',
          'HSS F349',
          'HSS F373',
          'HSS F399',
        ]),
        name: 'Literature',
      ),
    ],
  ),
  Minor(
    name: 'Entrepreneurship',
    courses: 5,
    units: 15,
    core: [
      _one('BITS F468'),
      ['BITS F482', 'ECON F414'],
      _one('ECON F212'),
    ],
    pools: [
      MinorPool(
        _each([
          'BITS F322',
          'BITS F323',
          'BITS F324',
          'BITS F325',
          'BITS F326',
          'BITS F427',
        ]),
      ),
    ],
  ),
  Minor(
    name: 'Film and Media',
    courses: 6,
    units: 18,
    core: _each(['GS F223', 'GS F244', 'GS F322']),
    pools: [
      MinorPool(
        _each([
          'GS F224',
          'GS F242',
          'GS F321',
          'GS F343',
          'HSS F332',
          'HSS F391',
        ]),
      ),
    ],
  ),
  Minor(
    name: 'Finance',
    courses: 5,
    units: 15,
    core: _each(['ECON F212', 'FIN F315']),
    pools: [
      MinorPool(
        _each([
          'ECON F241',
          'ECON F312',
          'ECON F355',
          'ECON F411',
          'ECON F413',
          'FIN F242',
          'FIN F243',
          'FIN F311',
          'FIN F312',
          'FIN F313',
          'FIN F314',
          'FIN F414',
        ]),
      ),
    ],
  ),
  Minor(
    name: 'Management',
    courses: 5,
    units: 15,
    core: _each(['BITS F428', 'MGTS F211', 'MGTS F314']),
    pools: [
      MinorPool(
        _each([
          'BITS F326',
          'BITS F330',
          'ECON F415',
          'ECON F434',
          'ECON F435',
          'HSS F328',
          'MF F219',
          'MF F319',
          'ME F443',
          'MGTS F311',
          'MGTS F313',
          'MGTS F315',
          'MGTS F316',
          'MGTS F351',
        ]),
      ),
    ],
  ),
  Minor(
    name: 'Materials Science and Engineering',
    courses: 5,
    units: 15,
    core: [
      ['CHE F243', 'ME F213'],
      _one('MST F331'),
      _one('MST F332'),
    ],
    pools: [
      MinorPool(
        _each([
          'BITS F416',
          'CHE F433',
          'CHEM F223',
          'CHEM F326',
          'CHEM F336',
          'ME F452',
          'MST F333',
          'MST F334',
          'MST F335',
          'MST F336',
          'MST F337',
          'MST F338',
          'MST F339',
          'PHY F379',
          'PHY F414',
          'PHY F416',
        ]),
      ),
    ],
  ),
  Minor(
    name: 'Nanoscience and Nanobiotechnology',
    courses: 5,
    units: 15,
    core: [
      _one('BIOT F422'),
      _one('BITS F416'),
      ['CHE F243', 'ME F216', 'MF F216'],
    ],
    pools: [
      MinorPool(
        _each([
          'BIO F417',
          'CHEM F223',
          'CHEM F327',
          'CHEM F328',
          'CHEM F333',
          'CHEM F336',
          'CHEM F414',
          'MST F333',
        ]),
        min: 2,
      ),
    ],
  ),
  Minor(
    name: 'Philosophy, Economics and Politics',
    courses: 6,
    units: 18,
    core: _each(['ECON F211', 'GS F211', 'HSS F235']),
    pools: [
      MinorPool(
        _each([
          'BITS F385',
          'GS F231',
          'GS F234',
          'GS F243',
          'GS F312',
          'GS F313',
          'GS F332',
          'GS F333',
          'HSS F232',
          'HSS F236',
          'HSS F315',
          'HSS F322',
          'HSS F331',
          'HSS F333',
          'HSS F343',
          'HSS F345',
          'HSS F346',
          'HSS F350',
          'HSS F353',
          'HSS F354',
          'HSS F355',
          'HSS F356',
        ]),
      ),
    ],
  ),
  Minor(
    name: 'Physics',
    courses: 5,
    units: 15,
    core: [
      ['PHY F212', 'ECE F212', 'EEE F212', 'INSTR F212'],
      _one('PHY F242'),
      _one('PHY F312'),
    ],
    pools: [
      MinorPool(
        _each([
          'BITS F316',
          'BITS F386',
          'PHY F211',
          'PHY F213',
          'PHY F214',
          'PHY F215',
          'PHY F241',
          'PHY F243',
          'PHY F244',
          'PHY F311',
          'PHY F313',
          'PHY F315',
          'PHY F318',
          'PHY F341',
          'PHY F342',
          'PHY F343',
          'PHY F346',
          'PHY F418',
          'PHY F426',
          'PHY F427',
          'PHY F428',
          'PHY F434',
        ]),
      ),
    ],
  ),
  Minor(
    name: 'Public Policy',
    courses: 5,
    units: 15,
    core: _each(['GS F233', 'GS F333']),
    pools: [
      MinorPool(
        _each([
          'HSS F232',
          'HSS F317',
          'HSS F322',
          'HSS F361',
          'HSS F362',
          'HSS F363',
        ]),
      ),
    ],
  ),
  Minor(
    name: 'Quantum Information and Technologies',
    courses: 5,
    units: 15,
    core: _each(['BITS F386']),
    pools: [
      MinorPool([
        ..._each(['BITS F463', 'BITS F464', 'CS F316']),
        ['PHY F242', 'PHY F345', 'CHEM F213'],
        ['PHY F420', 'PHY F318'],
        ..._each(['PHY F428', 'PHY F434']),
      ]),
    ],
  ),
  Minor(
    name: 'Robotics and Automation',
    courses: 5,
    units: 15,
    core: [
      _one('BITS F441'),
      ['EEE F242', 'INSTR F242', 'ECE F242'],
      _one('BITS F327'),
    ],
    pools: [
      MinorPool([
        ..._each([
          'BITS F312',
          'BITS F415',
          'BITS F442',
          'BITS F451',
          'BITS F464',
          'ECE F434',
          'EEE F411',
          'EEE F422',
          'EEE G512',
          'INSTR F343',
          'INSTR G611',
        ]),
        ['ME F221', 'MF F221'],
        ..._each(['ME F426', 'ME F432', 'MF F311', 'MSE G511']),
      ]),
    ],
  ),
  Minor(
    name: 'Semiconductor Devices and Technology',
    courses: 5,
    units: 15,
    core: [
      _one('EEE F437'),
      ['EEE F214', 'ECE F214', 'INSTR F214', 'ECOM F214'],
    ],
    pools: [
      MinorPool([
        _one('BITS F415'),
        ['EEE F216', 'ECE F216', 'INSTR F216'],
        ['EEE F423', 'ECE F423', 'INSTR F423'],
        ..._each([
          'EEE F477',
          'EEE G595',
          'MEL G514',
          'MST F331',
          'PHY F341',
          'PHY F379',
        ]),
      ]),
    ],
  ),
  Minor(
    name: 'Supply Chain Analytics',
    courses: 5,
    units: 15,
    core: _each(['BITS F455', 'MF F319', 'MF F422']),
    pools: [
      MinorPool([
        ..._each(['ME F443', 'MF F321', 'MF F418', 'MF F485']),
        ['MATH F212', 'ME F320', 'MF F320'],
        ..._each(['MATH F242', 'MATH F353']),
      ]),
    ],
  ),
  Minor(
    name: 'Water and Sanitation',
    courses: 5,
    units: 15,
    core: _each(['BIO F216', 'BIO F217']),
    pools: [
      MinorPool(
        _each([
          'BIO F266',
          'SAN G511',
          'SAN G512',
          'SAN G513',
          'SAN G514',
          'SAN G515',
        ]),
      ),
    ],
    projects: {'BIO F266'},
  ),
  Minor(
    name: 'Tissue Engineering',
    courses: 5,
    units: 15,
    core: _each(['BIO F352', 'BIO F422', 'MST F333']),
    pools: [
      MinorPool([
        ['BITS F417', 'ME F423'],
        ..._each([
          'BITS F418',
          'BIOT F422',
          'BIO F311',
          'CHE F414',
          'CHE F421',
          'DE G513',
          'ME F211',
          'ME F216',
          'ME F452',
        ]),
      ]),
    ],
  ),
];

Minor? minorNamed(String? name) =>
    minors.where((m) => m.name == name).firstOrNull;
