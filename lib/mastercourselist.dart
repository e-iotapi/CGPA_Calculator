class Mastercourselist {
  final String title;
  final String id;
  final int credits;

  Mastercourselist({
    required this.title,
    required this.id,
    required this.credits,
  });
}

// -1NC, -2CLR,-3GD, not included in cgcalculation- edit
List<Mastercourselist> mcourselist = [
  Mastercourselist(title: "Linear Algebra and Complex Variables", id: "MATH F102", credits: 3),
  Mastercourselist(title: "Innovation and Design Thinking", id: "BITS F102", credits: 1),
  Mastercourselist(title: "Oscillations and Waves", id: "PHY F101", credits: 3),
  Mastercourselist(title: "Fundamentals of Chemistry", id: "CHEM F101", credits: 3),
  Mastercourselist(title: "Social Conduct", id: "BITS F101", credits: 1),
  Mastercourselist(title: "Physical Well-being and Creativity", id: "BITS K101", credits: 1),
  Mastercourselist(title: "Engineering Design and Prototyping", id: "BITS F103", credits: 4),
  Mastercourselist(title: "Introduction to Biological Sciences", id: "BIO F101", credits: 3),
  Mastercourselist(title: "Introduction to Oscillations and Waves", id: "PHY F102", credits: 3),
  Mastercourselist(title: "Multivariable Calculus", id: "MATH F101", credits: 3),
  Mastercourselist(title: "Computer Programming", id: "CS F111", credits: 4),
  Mastercourselist(title: "Mathematics I", id: "MATH F111", credits: 3),
  Mastercourselist(title: "Thermodynamics", id: "BITS F111", credits: 3),
  Mastercourselist(title: "Engineering Graphics", id: "BITS F110", credits: 2),
  Mastercourselist(
    title: "Technical Report Writing",
    id: "BITS F112",
    credits: 2,
  ),
  Mastercourselist(title: "General Mathematics I", id: "BITS F113", credits: 3),
  Mastercourselist(
    title: "General Mathematics II",
    id: "BITS F114",
    credits: 3,
  ),
  Mastercourselist(
    title: "Material Science and Engineering",
    id: "BITS F201",
    credits: 3,
  ),
  Mastercourselist(title: "General Chemistry", id: "CHEM F111", credits: 3),
  Mastercourselist(title: "Mathematics II", id: "MATH F112", credits: 3),
  Mastercourselist(
    title: "Mechanical Oscillations and Waves",
    id: "PHY F111",
    credits: 3,
  ),
  Mastercourselist(
    title: "Probability and Statistics",
    id: "MATH F113",
    credits: 3,
  ),
  Mastercourselist(title: "Workshop Practice", id: "ME F110", credits: 2),
  Mastercourselist(title: "Workshop Practice", id: "ME F112", credits: 2),
  Mastercourselist(title: "Chemistry Laboratory", id: "CHEM F110", credits: 1),
  Mastercourselist(title: "Physics Laboratory", id: "PHY F110", credits: 1),

  //abcd
  Mastercourselist(
    title: "Principles of Aerodynamics",
    id: "AN F311",
    credits: 3,
  ),
  Mastercourselist(title: "Aircraft Propulsion", id: "AN F312", credits: 3),
  Mastercourselist(
    title: "Flight Mechanics and Controls",
    id: "AN F313",
    credits: 3,
  ),
  Mastercourselist(title: "Introduction to Flight", id: "AN F314", credits: 3),
  Mastercourselist(title: "Aircraft Structures", id: "AN F315", credits: 3),
  Mastercourselist(title: "Computer Programming", id: "CS F111", credits: 4),
  Mastercourselist(
    title: "Data Structures & Algorithms",
    id: "CS F211",
    credits: 4,
  ),
  Mastercourselist(title: "Database Systems", id: "CS F212", credits: 4),
  Mastercourselist(
    title: "Object Oriented Programming",
    id: "CS F213",
    credits: 4,
  ),
  Mastercourselist(
    title: "Logic in Computer Science",
    id: "CS F214",
    credits: 3,
  ),
  Mastercourselist(title: "Digital Design", id: "CS F215", credits: 4),
  Mastercourselist(
    title: "Discrete Structures for Computer Science",
    id: "CS F222",
    credits: 3,
  ),
  Mastercourselist(
    title: "Microprocessors & Interfacing",
    id: "CS F241",
    credits: 4,
  ),
  Mastercourselist(title: "Study Project", id: "CS F266", credits: 3),
  Mastercourselist(
    title: "Principles of Programming Languages",
    id: "CS F301",
    credits: 2,
  ),
  Mastercourselist(title: "Computer Networks", id: "CS F303", credits: 4),
  Mastercourselist(
    title: "Software Development for Portable Devices",
    id: "CS F314",
    credits: 3,
  ),
  Mastercourselist(
    title: "Information and Communication Technologies and Development",
    id: "CS F315",
    credits: 3,
  ),
  Mastercourselist(
    title: "Quantum Architecture and Programming",
    id: "CS F316",
    credits: 3,
  ),
  Mastercourselist(title: "Reinforcement Learning", id: "CS F317", credits: 3),
  Mastercourselist(
    title: "Foundations of Data Science",
    id: "CS F320",
    credits: 3,
  ),
  Mastercourselist(title: "Computer Architecture", id: "CS F342", credits: 4),
  Mastercourselist(title: "Theory of Computation", id: "CS F351", credits: 3),
  Mastercourselist(title: "Compiler Construction", id: "CS F363", credits: 3),
  Mastercourselist(
    title: "Design & Analysis of Algorithms",
    id: "CS F364",
    credits: 3,
  ),
  Mastercourselist(title: "Lab Project", id: "CS F366", credits: 3),
  Mastercourselist(title: "Lab Project", id: "CS F367", credits: 3),
  Mastercourselist(title: "Operating Systems", id: "CS F372", credits: 3),
  Mastercourselist(title: "Design Project", id: "CS F376", credits: 3),
  Mastercourselist(title: "Design Project", id: "CS F377", credits: 3),
  Mastercourselist(title: "Multimedia Computing", id: "CS F401", credits: 3),
  Mastercourselist(title: "Computational Geometry", id: "CS F402", credits: 3),
  Mastercourselist(
    title: "Computer Crime and Forensics",
    id: "CS F404",
    credits: 2,
  ),
  Mastercourselist(title: "Ethical Hacking", id: "CS F406", credits: 3),
  Mastercourselist(title: "Artificial Intelligence", id: "CS F407", credits: 3),
  Mastercourselist(
    title: "Internetworking Technologies",
    id: "CS F413",
    credits: 3,
  ),
  Mastercourselist(title: "Data Mining", id: "CS F415", credits: 3),
  Mastercourselist(title: "Parallel Computing", id: "CS F422", credits: 3),
  Mastercourselist(
    title: "Software for Embedded Systems",
    id: "CS F424",
    credits: 4,
  ),
  Mastercourselist(title: "Deep Learning", id: "CS F425", credits: 3),
  Mastercourselist(title: "Graph Mining", id: "CS F426", credits: 4),
  Mastercourselist(
    title: "Performance Analysis of Computer Networks",
    id: "CS F427",
    credits: 3,
  ),
  Mastercourselist(
    title: "Special topic in Computer Science",
    id: "CS F428",
    credits: 1,
  ),
  Mastercourselist(
    title: "Natural Language Processing",
    id: "CS F429",
    credits: 3,
  ),
  Mastercourselist(
    title: "Approximation Algorithms",
    id: "CS F430",
    credits: 3,
  ),
  Mastercourselist(
    title: "Combinatorial Optimization",
    id: "CS F431",
    credits: 3,
  ),
  Mastercourselist(
    title: "Brain-inspired Deep Learning",
    id: "CS F432",
    credits: 3,
  ),
  Mastercourselist(
    title: "Computational Neuroscience",
    id: "CS F433",
    credits: 3,
  ),
  Mastercourselist(title: "Generative AI", id: "CS F437", credits: 3),
  Mastercourselist(
    title: "Selected Topics from Computer Science",
    id: "CS F441",
    credits: 3,
  ),
  Mastercourselist(title: "Real Time Systems", id: "CS F444", credits: 3),
  Mastercourselist(
    title: "Data Storage Technologies and Networks",
    id: "CS F446",
    credits: 3,
  ),
  Mastercourselist(
    title: "Combinatorial Mathematics",
    id: "CS F451",
    credits: 3,
  ),
  Mastercourselist(
    title: "Information Security Project",
    id: "CS F468",
    credits: 3,
  ),
  Mastercourselist(title: "Information Retrieval", id: "CS F469", credits: 3),
  Mastercourselist(title: "Special Projects", id: "CS F491", credits: 3),
  Mastercourselist(title: "Network Security", id: "CS G513", credits: 4),
  Mastercourselist(title: "Social Media Analytics", id: "CS G519", credits: 4),
  Mastercourselist(title: "Advanced Data Mining", id: "CS G520", credits: 4),
  Mastercourselist(title: "Cloud Computing", id: "CS G527", credits: 5),
  Mastercourselist(
    title: "Reconfigurable Computing",
    id: "CS G553",
    credits: 5,
  ),
  Mastercourselist(title: "Distributed Computing", id: "CS G557", credits: 5),
  Mastercourselist(title: "Mechanics of Solids", id: "CE F211", credits: 3),
  Mastercourselist(title: "Transport Phenomena", id: "CE F212", credits: 3),
  Mastercourselist(title: "Surveying", id: "CE F213", credits: 4),
  Mastercourselist(title: "Construction Materials", id: "CE F214", credits: 3),

  // abcdefgh
  Mastercourselist(title: "Biological Chemistry", id: "BIOT F211", credits: 3),
  Mastercourselist(title: "Microbiology", id: "BIOT F212", credits: 4),
  Mastercourselist(title: "Cell Biology", id: "BIOT F213", credits: 3),
  Mastercourselist(title: "Biophysics", id: "BIOT F215", credits: 3),
  Mastercourselist(
    title: "Genetic Engineering Techniques",
    id: "BIOT F241",
    credits: 4,
  ),
  Mastercourselist(
    title: "Introduction to Bioinformatics",
    id: "BIOT F242",
    credits: 3,
  ),
  Mastercourselist(title: "Genetics", id: "BIOT F243", credits: 3),
  Mastercourselist(
    title: "Instrumental Methods of Analysis",
    id: "BIOT F244",
    credits: 4,
  ),
  Mastercourselist(
    title: "Introduction to Environmental Biotechnology",
    id: "BIOT F245",
    credits: 3,
  ),
  Mastercourselist(title: "Study Project", id: "BIOT F266", credits: 3),
  Mastercourselist(
    title: "Recombinant DNA Technology",
    id: "BIOT F311",
    credits: 3,
  ),
  Mastercourselist(
    title: "Industrial Microbiology and Bioprocess Engineering",
    id: "BIOT F314",
    credits: 4,
  ),
  Mastercourselist(title: "Immunology", id: "BIOT F342", credits: 3),
  Mastercourselist(
    title: "Experiments in Biotechnology",
    id: "BIOT F343",
    credits: 3,
  ),
  Mastercourselist(title: "Downstream Processing", id: "BIOT F344", credits: 3),
  Mastercourselist(title: "Proteomics", id: "BIOT F345", credits: 3),
  Mastercourselist(title: "Proteomics", id: "BIOT F345", credits: 3),
  Mastercourselist(title: "Genomics", id: "BIOT F346", credits: 3),
  Mastercourselist(title: "Immunotechnology", id: "BIOT F347", credits: 3),
  Mastercourselist(
    title: "Cell and Tissue Culture Technology",
    id: "BIOT F352",
    credits: 3,
  ),
  Mastercourselist(title: "Lab Project", id: "BIOT F366", credits: 3),
  Mastercourselist(title: "Lab Project", id: "BIOT F367", credits: 3),
  Mastercourselist(title: "Design Project", id: "BIOT F376", credits: 3),
  Mastercourselist(title: "Design Project", id: "BIOT F377", credits: 3),
  Mastercourselist(
    title: "Molecular Biology of the Cell",
    id: "BIOT F413",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Pharmaceutical Biotechnology",
    id: "BIOT F416",
    credits: 3,
  ),
  Mastercourselist(title: "Biomolecular Modeling", id: "BIOT F417", credits: 3),
  Mastercourselist(
    title: "Introduction to Plant Biotechnology",
    id: "BIOT F420",
    credits: 3,
  ),
  Mastercourselist(title: "Nanobiotechnology", id: "BIOT F422", credits: 3),
  Mastercourselist(
    title: "Drug Design and Delivery",
    id: "BIOT F423",
    credits: 3,
  ),
  Mastercourselist(title: "Food Biotechnology", id: "BIOT F424", credits: 3),

  // abcdefg
  Mastercourselist(title: "Biology Laboratory", id: "BIO F110", credits: 1),
  Mastercourselist(title: "General Biology", id: "BIO F111", credits: 3),
  Mastercourselist(title: "Introductory Biology", id: "BIO F201", credits: 4),
  Mastercourselist(title: "Biological Chemistry", id: "BIO F211", credits: 3),
  Mastercourselist(title: "Microbiology", id: "BIO F212", credits: 4),
  Mastercourselist(title: "Cell Biology", id: "BIO F213", credits: 3),
  Mastercourselist(title: "Integrated Biology", id: "BIO F214", credits: 3),
  Mastercourselist(title: "Biophysics", id: "BIO F215", credits: 3),
  Mastercourselist(
    title: "Water, Sanitation and Solid Waste Management",
    id: "BIO F216",
    credits: 3,
  ),
  Mastercourselist(
    title: "Laboratory for Water, Sanitation and Solid Waste Management",
    id: "BIO F217",
    credits: 3,
  ),
  Mastercourselist(
    title: "Biology Project Laboratory",
    id: "BIO F231",
    credits: 3,
  ),
  Mastercourselist(
    title: "Ecology & Environmental Science",
    id: "BIO F241",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Bioinformatics",
    id: "BIO F242",
    credits: 3,
  ),
  Mastercourselist(title: "Genetics", id: "BIO F243", credits: 3),
  Mastercourselist(
    title: "Instrumental Methods of Analysis",
    id: "BIO F244",
    credits: 4,
  ),
  Mastercourselist(title: "Study Project", id: "BIO F266", credits: 3),
  Mastercourselist(
    title: "Recombinant DNA Technology",
    id: "BIO F311",
    credits: 3,
  ),
  Mastercourselist(title: "Plant Physiology", id: "BIO F312", credits: 3),
  Mastercourselist(title: "Animal Physiology", id: "BIO F313", credits: 3),
  Mastercourselist(title: "Conservation Biology", id: "BIO F314", credits: 3),
  Mastercourselist(
    title: "Applied Nutrition and Nutraceuticals",
    id: "BIO F315",
    credits: 2,
  ),
  Mastercourselist(title: "Developmental Biology", id: "BIO F341", credits: 3),
  Mastercourselist(title: "Immunology", id: "BIO F342", credits: 3),
  Mastercourselist(
    title: "Cell and Tissue Culture Technology",
    id: "BIO F352",
    credits: 4,
  ),
  Mastercourselist(title: "Lab Project", id: "BIO F366", credits: 3),
  Mastercourselist(title: "Lab Project", id: "BIO F367", credits: 3),
  Mastercourselist(title: "Design Project", id: "BIO F376", credits: 3),
  Mastercourselist(title: "Design Project", id: "BIO F377", credits: 3),
  Mastercourselist(title: "Laboratory", id: "BIO F411", credits: 3),
  Mastercourselist(
    title: "Molecular Biology of Cell",
    id: "BIO F413",
    credits: 3,
  ),
  Mastercourselist(title: "Biomolecular Modelling", id: "BIO F417", credits: 3),
  Mastercourselist(
    title: "Genetic Engineering Techniques",
    id: "BIO F418",
    credits: 4,
  ),
  Mastercourselist(title: "Molecular Evolution", id: "BIO F419", credits: 3),
  Mastercourselist(title: "Enzymology", id: "BIO F421", credits: 3),
  Mastercourselist(
    title: "Reproductive Physiology",
    id: "BIO F431",
    credits: 3,
  ),
  Mastercourselist(
    title: "Biochemical Engineering",
    id: "BIO F441",
    credits: 3,
  ),
  Mastercourselist(title: "Bioprocess Technology", id: "BIO F451", credits: 3),
  Mastercourselist(title: "Special Projects", id: "BIO F491", credits: 3),
  Mastercourselist(
    title: "Molecular Mechanism of Gene Expression",
    id: "BIO G512",
    credits: 5,
  ),
  Mastercourselist(
    title: "Microbial and Fermentation Technology",
    id: "BIO G513",
    credits: 5,
  ),
  Mastercourselist(title: "Molecular Immunology", id: "BIO G514", credits: 4),
  Mastercourselist(
    title: "Stem Cell and Regenerative Biology",
    id: "BIO G515",
    credits: 4,
  ),
  Mastercourselist(title: "Interferon Technology", id: "BIO G522", credits: 4),
  Mastercourselist(
    title: "Advanced and Applied Microbiology",
    id: "BIO G523",
    credits: 5,
  ),
  Mastercourselist(title: "Animal Cell Technology", id: "BIO G524", credits: 5),
  Mastercourselist(
    title: "Environmental Biotechnology & Waste Management",
    id: "BIO G525",
    credits: 5,
  ),
  Mastercourselist(title: "Cancer Biology", id: "BIO G526", credits: 5),
  Mastercourselist(
    title: "Biostatistics and Biomodeling",
    id: "BIO G532",
    credits: 4,
  ),
  Mastercourselist(
    title: "Bioremediation and Biometallurgy",
    id: "BIO G544",
    credits: 5,
  ),
  Mastercourselist(
    title: "Molecular Parasitology and Vector Biology",
    id: "BIO G545",
    credits: 5,
  ),
  Mastercourselist(
    title: "Advances in Recombinant DNA Technology",
    id: "BIO G561",
    credits: 5,
  ),
  Mastercourselist(
    title: "Recent Developments in Biology",
    id: "BIO G570",
    credits: 1,
  ),
  Mastercourselist(title: "Human Genetics", id: "BIO G612", credits: 5),
  Mastercourselist(
    title: "Membrane and Liposome Technology",
    id: "BIO G631",
    credits: 4,
  ),
  Mastercourselist(title: "Transgenic Technology", id: "BIO G632", credits: 5),
  Mastercourselist(
    title: "Experimental Techniques",
    id: "BIO G642",
    credits: 4,
  ),
  Mastercourselist(title: "Plant Biotechnology", id: "BIO G643", credits: 5),
  Mastercourselist(
    title: "Protein and Enzyme Bioengineering",
    id: "BIO G651",
    credits: 5,
  ),
  Mastercourselist(title: "Gene Toxicology", id: "BIO G661", credits: 4),
  Mastercourselist(
    title: "Bioconversion Technology",
    id: "BIO G671",
    credits: 5,
  ),

  //abcdef
  Mastercourselist(title: "Mechanics of Solids", id: "CE F211", credits: 3),
  Mastercourselist(title: "Surveying", id: "CE F213", credits: 4),
  Mastercourselist(
    title: "Civil Engineering Materials",
    id: "CE F230",
    credits: 4,
  ),
  Mastercourselist(title: "Fluid Mechanics", id: "CE F231", credits: 3),
  Mastercourselist(title: "Analysis of Structures", id: "CE F241", credits: 3),
  Mastercourselist(
    title: "Construction Planning and Technology",
    id: "CE F242",
    credits: 3,
  ),
  Mastercourselist(title: "Soil Mechanics", id: "CE F243", credits: 4),
  Mastercourselist(title: "Highway Engineering", id: "CE F244", credits: 4),
  Mastercourselist(title: "Study Project", id: "CE F266", credits: 3),
  Mastercourselist(
    title: "Design of Concrete Structures",
    id: "CE F311",
    credits: 4,
  ),
  Mastercourselist(title: "Hydraulics Engineering", id: "CE F312", credits: 4),
  Mastercourselist(title: "Foundation Engineering", id: "CE F313", credits: 3),
  Mastercourselist(
    title: "Design of Reinforced Concrete Structures",
    id: "CE F320",
    credits: 3,
  ),
  Mastercourselist(title: "Engineering Hydrology", id: "CE F321", credits: 3),
  Mastercourselist(
    title: "Water & Waste Water Treatment",
    id: "CE F342",
    credits: 4,
  ),
  Mastercourselist(
    title: "Design of Steel Structures",
    id: "CE F343",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Environmental Engineering",
    id: "CE F323",
    credits: 3,
  ),
  Mastercourselist(title: "Numerical Analysis", id: "CE F324", credits: 3),
  Mastercourselist(
    title: "Fundamentals of Rock Mechanics",
    id: "CE F325",
    credits: 3,
  ),
  Mastercourselist(
    title: "Computational Geomechanics",
    id: "CE F345",
    credits: 3,
  ),
  Mastercourselist(title: "Lab Project", id: "CE F366", credits: 3),
  Mastercourselist(title: "Lab Project", id: "CE F367", credits: 3),
  Mastercourselist(title: "Design Project", id: "CE F376", credits: 3),
  Mastercourselist(title: "Design Project", id: "CE F377", credits: 3),
  Mastercourselist(
    title: "Operation Research for Engineers",
    id: "CE F411",
    credits: 3,
  ),
  Mastercourselist(title: "Disaster Management", id: "CE F412", credits: 3),
  Mastercourselist(
    title: "Advanced Structural Design",
    id: "CE F413",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Environmental Engineering",
    id: "CE F414",
    credits: 3,
  ),
  Mastercourselist(
    title: "Design of Prestressed Concrete Structure",
    id: "CE F415",
    credits: 3,
  ),
  Mastercourselist(
    title: "Computer Applications in Civil Engineering",
    id: "CE F416",
    credits: 4,
  ),
  Mastercourselist(
    title: "Applications of Artificial Intelligence in Civil Engg.",
    id: "CE F417",
    credits: 3,
  ),
  Mastercourselist(
    title: "Geotechnical Earthquake Engg. and Machine Foundation",
    id: "CE F419",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Bridge Engineering",
    id: "CE F420",
    credits: 3,
  ),
  Mastercourselist(
    title: "Analysis and Design of FRP Reinforced Concrete Structures",
    id: "CE F421",
    credits: 3,
  ),
  Mastercourselist(title: "Urban Hydrology", id: "CE F422", credits: 3),
  Mastercourselist(
    title: "Green Buildings and Energy Conservation",
    id: "CE F423",
    credits: 3,
  ),
  Mastercourselist(
    title: "Airport, Railways and Waterways",
    id: "CE F425",
    credits: 3,
  ),
  Mastercourselist(
    title: "Geosynthetics and Reinforced Soil Structure",
    id: "CE F426",
    credits: 3,
  ),
  Mastercourselist(
    title: "System Modeling and Analysis",
    id: "CE F427",
    credits: 3,
  ),
  Mastercourselist(
    title: "Earthquake Resistant Design and Construction",
    id: "CE F428",
    credits: 3,
  ),
  Mastercourselist(
    title: "Design of Foundation Systems",
    id: "CE F429",
    credits: 3,
  ),
  Mastercourselist(
    title: "Design of Advanced Concrete Structures",
    id: "CE F430",
    credits: 3,
  ),
  Mastercourselist(
    title: "Principles of Geographical Information Systems",
    id: "CE F431",
    credits: 4,
  ),
  Mastercourselist(title: "Structural Dynamics", id: "CE F432", credits: 3),
  Mastercourselist(
    title: "Remote Sensing and Image Processing",
    id: "CE F433",
    credits: 4,
  ),
  Mastercourselist(
    title: "Environmental Impact Assessment",
    id: "CE F434",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Finite Element Methods",
    id: "CE F435",
    credits: 3,
  ),
  Mastercourselist(title: "Special Projects", id: "CE F491", credits: 3),

  //abcdef
  Mastercourselist(
    title: "Bioethics and Biosafety",
    id: "BITS F467",
    credits: 3,
  ),
  Mastercourselist(title: "Introduction to MEMS", id: "BITS F415", credits: 4),
  Mastercourselist(
    title: "Introduction to Nanoscience",
    id: "BITS F416",
    credits: 3,
  ),
  Mastercourselist(
    title: "Microfluidics and its application",
    id: "BITS F417",
    credits: 4,
  ),
  Mastercourselist(
    title: "Introduction to Biomedical Engineering",
    id: "BITS F418",
    credits: 4,
  ),
  Mastercourselist(
    title: "Nanotechnology for Renewable Energy and Environment",
    id: "BITS F429",
    credits: 4,
  ),
  Mastercourselist(
    title: "Multicriterion Decision Making in Engg. and Management",
    id: "BITS F313",
    credits: 3,
  ),
  Mastercourselist(title: "Image Processing", id: "BITS F311", credits: 3),
  Mastercourselist(
    title: "Neural Networks and Fuzzy Logic",
    id: "BITS F312",
    credits: 3,
  ),
  Mastercourselist(
    title: "Fuzzy Logic and Applications",
    id: "BITS F343",
    credits: 3,
  ),
  Mastercourselist(
    title: "Information Law and Cyber Law",
    id: "BITS F345",
    credits: 3,
  ),
  Mastercourselist(
    title: "Nonlinear Dynamics and Chaos",
    id: "BITS F351",
    credits: 3,
  ),
  Mastercourselist(
    title: "Human – Computer Interaction",
    id: "BITS F364",
    credits: 3,
  ),
  Mastercourselist(
    title: "Quantum Information and Computation",
    id: "BITS F386",
    credits: 3,
  ),
  Mastercourselist(title: "Selected Readings", id: "BITS F407", credits: 3),
  Mastercourselist(title: "Practice School II", id: "BITS F412", credits: 20),
  Mastercourselist(title: "Practice School II", id: "BITS F413", credits: 20),
  Mastercourselist(title: "Blockchain Technology", id: "BITS F452", credits: 3),
  Mastercourselist(
    title: "Computational Learning Theory",
    id: "BITS F453",
    credits: 3,
  ),
  Mastercourselist(
    title: "Bio-Inspired Intelligence: Algorithms and Applications",
    id: "BITS F454",
    credits: 3,
  ),
  Mastercourselist(title: "Cryptography", id: "BITS F463", credits: 3),
  Mastercourselist(title: "Machine Learning", id: "BITS F464", credits: 3),
  Mastercourselist(title: "Enterprise Computing", id: "BITS F465", credits: 4),
  Mastercourselist(
    title: "Service Oriented Computing",
    id: "BITS F466",
    credits: 4,
  ),
  Mastercourselist(
    title: "Game Theory and Its Applications",
    id: "BITS F314",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Cognitive Neuroscience",
    id: "BITS F315",
    credits: 3,
  ),
  Mastercourselist(
    title: "Non Linear Dynamics and Chaos",
    id: "BITS F316",
    credits: 3,
  ),
  Mastercourselist(title: "Renewable Energy", id: "BITS F462", credits: 3),
  Mastercourselist(
    title: "Introduction to Gender Studies",
    id: "BITS F385",
    credits: 3,
  ),
  Mastercourselist(
    title: "Science, Technology and Modernity",
    id: "BITS F214",
    credits: 3,
  ),
  Mastercourselist(
    title: "Environment, Development and Climate Change",
    id: "BITS F217",
    credits: 3,
  ),
  Mastercourselist(
    title: "General Mathematics II",
    id: "BITS F218",
    credits: 3,
  ),
  Mastercourselist(title: "Process Engineering", id: "BITS F219", credits: 3),
  Mastercourselist(title: "Practice School I", id: "BITS F221", credits: 5),
  Mastercourselist(title: "Environmental Studies", id: "BITS F225", credits: 3),
  Mastercourselist(
    title: "Soft Skills for Professionals",
    id: "BITS F226",
    credits: 3,
  ),
  Mastercourselist(title: "Foundations of Data Structures and Algorithms", id: "BITS F232", credits: 4),
  Mastercourselist(title: "Practice School I", id: "BITS F231", credits: 5),
  Mastercourselist(title: "Practice School I", id: "BITS F241", credits: 3),
  Mastercourselist(
    title: "Innovation Ecosystem and the Future of Work",
    id: "BITS F328",
    credits: 4,
  ),
  Mastercourselist(
    title: "Humanistic Theories of Science and Technology",
    id: "BITS F399",
    credits: 3,
  ),
  Mastercourselist(
    title: "Management of Cross Cultural Engineering Teams",
    id: "BITS F419",
    credits: 3,
  ),
  Mastercourselist(title: "Thesis", id: "BITS F421", credits: 16),
  Mastercourselist(title: "Thesis", id: "BITS F422", credits: 16),
  Mastercourselist(title: "Thesis", id: "BITS F423", credits: 9),
  Mastercourselist(title: "Thesis", id: "BITS F424", credits: 9),
  Mastercourselist(title: "Introduction to IPR", id: "BITS F211", credits: 1),
  Mastercourselist(
    title: "Introduction to Human Rights",
    id: "BITS F212",
    credits: 1,
  ),
  Mastercourselist(
    title: "Introduction to Environmental studies",
    id: "BITS F213",
    credits: 1,
  ),
  Mastercourselist(
    title:
        "Applications of Bio-Medical Instrumentation Techniques in Healthcare",
    id: "BITS F215",
    credits: 2,
  ),
  Mastercourselist(title: "Environmental Studies", id: "BITS F225", credits: 3),
  Mastercourselist(
    title: "Theoretical Neuroscience",
    id: "BITS F317",
    credits: 3,
  ),
  Mastercourselist(
    title: "Negotiation Skills and Techniques",
    id: "BITS F319",
    credits: 2,
  ),
  Mastercourselist(title: "Managerial Skills", id: "BITS F320", credits: 2),
  Mastercourselist(
    title: "Legal and Economic Environment of Business",
    id: "BITS F321",
    credits: 4,
  ),
  Mastercourselist(
    title: "Venture Team Development and Organisation",
    id: "BITS F322",
    credits: 3,
  ),
  Mastercourselist(title: "Venture Finance", id: "BITS F323", credits: 3),
  Mastercourselist(
    title: "Strategy For Entrepreneur",
    id: "BITS F324",
    credits: 3,
  ),
  Mastercourselist(
    title: "New Product and Service Design",
    id: "BITS F325",
    credits: 3,
  ),
  Mastercourselist(
    title: "Design Thinking for Innovation and Entrepreneurship",
    id: "BITS F326",
    credits: 3,
  ),
  Mastercourselist(title: "AI for Robotics", id: "BITS F327", credits: 3),
  Mastercourselist(
    title: "Quantum Information and Computation",
    id: "BITS F331",
    credits: 3,
  ),
  Mastercourselist(
    title: "Project on Organisational Aspects",
    id: "BITS F333",
    credits: 3,
  ),
  Mastercourselist(
    title: "Project on Organisational Aspects",
    id: "BITS F334",
    credits: 3,
  ),
  Mastercourselist(
    title: "Data Communications and Networks",
    id: "BITS F372",
    credits: 3,
  ),
  Mastercourselist(title: "TIC Projects", id: "BITS F381", credits: 3),
  Mastercourselist(title: "Reading Course", id: "BITS F382", credits: 3),
  Mastercourselist(title: "TIC Projects", id: "BITS F383", credits: 3),
  Mastercourselist(title: "Creative Multimedia", id: "BITS F398", credits: 3),
  Mastercourselist(
    title: "Introduction to Bioinformatics",
    id: "BITS F414",
    credits: 3,
  ),
  Mastercourselist(title: "Digital Marketing", id: "BITS F427", credits: 3),
  Mastercourselist(
    title: "Essentials of Strategic Management",
    id: "BITS F428",
    credits: 3,
  ),
  Mastercourselist(
    title: "renewable Energy Laboratory",
    id: "BITS F430",
    credits: 2,
  ),
  Mastercourselist(
    title: "Flexible Manufacturing Systems",
    id: "BITS F431",
    credits: 3,
  ),
  Mastercourselist(
    title: "Supply Chain Analytics",
    id: "BITS F433",
    credits: 4,
  ),
  Mastercourselist(
    title: "Technical Communication",
    id: "BITS F437",
    credits: 3,
  ),
  Mastercourselist(title: "Thesis", id: "BITS F421", credits: 16),
  Mastercourselist(title: "Robotics", id: "BITS F441", credits: 3),
  Mastercourselist(
    title: "Remote Sensing and Image Processing",
    id: "BITS F442",
    credits: 3,
  ),
  Mastercourselist(
    title: "Artificial Intelligence",
    id: "BITS F444",
    credits: 3,
  ),
  Mastercourselist(
    title: "Neural Networks and Applications",
    id: "BITS F445",
    credits: 3,
  ),
  Mastercourselist(title: "Pattern Recognition", id: "BITS F446", credits: 3),
  Mastercourselist(title: "Multimedia Computing", id: "BITS F447", credits: 3),
  Mastercourselist(
    title: "Retail Management Systems",
    id: "BITS F448",
    credits: 3,
  ),
  Mastercourselist(title: "Financial Engineering", id: "BITS F449", credits: 3),
  Mastercourselist(title: "Software Engineering", id: "BITS F461", credits: 3),
  Mastercourselist(title: "New Venture Creation", id: "BITS F468", credits: 3),
  Mastercourselist(
    title: "Financing Infrastructure Projects",
    id: "BITS F469",
    credits: 3,
  ),
  Mastercourselist(
    title: "Creating and Leading Entrepreneurial Organisations",
    id: "BITS F482",
    credits: 3,
  ),
  Mastercourselist(
    title: "Services Management Systems",
    id: "BITS F488",
    credits: 3,
  ),
  Mastercourselist(
    title: "Enterprise Resource Planning",
    id: "BITS F489",
    credits: 3,
  ),
  Mastercourselist(title: "Project Management", id: "BITS F490", credits: 4),
  Mastercourselist(
    title: "Business Analysis and Valuation",
    id: "BITS F493",
    credits: 3,
  ),
  Mastercourselist(
    title: "Environmental Impact Assessment",
    id: "BITS F494",
    credits: 4,
  ),
  Mastercourselist(
    title: "Introduction to Business Sustainability",
    id: "BITS G516",
    credits: 3,
  ),
  Mastercourselist(
    title: "Cross Cultural Management",
    id: "BITS G517",
    credits: 3,
  ),

  //abcdef
  Mastercourselist(
    title: "Chemical Process Calculations",
    id: "CHE F211",
    credits: 3,
  ),
  Mastercourselist(title: "Fluid Mechanics", id: "CHE F212", credits: 3),
  Mastercourselist(
    title: "Chemical Engineering Thermodynamics",
    id: "CHE F213",
    credits: 3,
  ),
  Mastercourselist(title: "Engineering Chemistry", id: "CHE F214", credits: 3),
  Mastercourselist(title: "Heat Transfer", id: "CHE F241", credits: 3),
  Mastercourselist(
    title: "Numerical Methods for Chemical Engineers",
    id: "CHE F242",
    credits: 3,
  ),
  Mastercourselist(
    title: "Material Science and Engineering",
    id: "CHE F243",
    credits: 3,
  ),
  Mastercourselist(title: "Separation Processes I", id: "CHE F244", credits: 3),
  Mastercourselist(title: "Study Project", id: "CHE F266", credits: 3),
  Mastercourselist(
    title: "Kinetics and Reactor Design",
    id: "CHE F311",
    credits: 3,
  ),
  Mastercourselist(
    title: "Chemical Engineering Lab I",
    id: "CHE F312",
    credits: 3,
  ),
  Mastercourselist(
    title: "Separation Processes II",
    id: "CHE F313",
    credits: 3,
  ),
  Mastercourselist(
    title: "Process Design Principles I",
    id: "CHE F314",
    credits: 3,
  ),
  Mastercourselist(
    title: "Chemical Engineering Lab II",
    id: "CHE F341",
    credits: 3,
  ),
  Mastercourselist(
    title: "Process Dynamics and Control",
    id: "CHE F342",
    credits: 3,
  ),
  Mastercourselist(
    title: "Process Design Principles II",
    id: "CHE F343",
    credits: 3,
  ),
  Mastercourselist(title: "Lab Project", id: "CHE F366", credits: 3),
  Mastercourselist(title: "Lab Project", id: "CHE F367", credits: 3),
  Mastercourselist(title: "Design Project", id: "CHE F376", credits: 3),
  Mastercourselist(title: "Design Project", id: "CHE F377", credits: 3),
  Mastercourselist(
    title: "Machine Learning for Chemical Engineers",
    id: "CHE F315",
    credits: 3,
  ),
  Mastercourselist(
    title: "Environmental Pollution Control",
    id: "CHE F411",
    credits: 3,
  ),
  Mastercourselist(
    title: "Process Equipment Design",
    id: "CHE F412",
    credits: 3,
  ),
  Mastercourselist(title: "Process Plant Safety", id: "CHE F413", credits: 3),
  Mastercourselist(title: "Transport Phenomena", id: "CHE F414", credits: 3),
  Mastercourselist(
    title: "Molecular and Statistical Thermodynamics",
    id: "CHE F415",
    credits: 3,
  ),
  Mastercourselist(
    title: "Process Plant Design Project I",
    id: "CHE F416",
    credits: 3,
  ),
  Mastercourselist(
    title: "Process Plant Design Project II",
    id: "CHE F417",
    credits: 3,
  ),
  Mastercourselist(
    title: "Modelling and Simulation in Chemical Engineering",
    id: "CHE F418",
    credits: 3,
  ),
  Mastercourselist(
    title: "Chemical Process Technology",
    id: "CHE F419",
    credits: 3,
  ),
  Mastercourselist(
    title: "Bio-chemical Engineering",
    id: "CHE F421",
    credits: 3,
  ),
  Mastercourselist(
    title: "Petroleum Refining Technology",
    id: "CHE F422",
    credits: 3,
  ),
  Mastercourselist(
    title: "Membrane Science and Engineering",
    id: "CHE F423",
    credits: 3,
  ),
  Mastercourselist(
    title: "Rheology of Complex Fluids",
    id: "CHE F424",
    credits: 3,
  ),
  Mastercourselist(title: "Corrosion Engineering", id: "CHE F433", credits: 3),
  Mastercourselist(
    title: "Advanced Process Control",
    id: "CHE F471",
    credits: 3,
  ),
  Mastercourselist(title: "Special Projects", id: "CHE F491", credits: 3),
  Mastercourselist(
    title: "Atomic and Molecular Simulations",
    id: "CHE F497",
    credits: 3,
  ),
  Mastercourselist(
    title: "Colloids and Interface Engineering",
    id: "CHE F498",
    credits: 3,
  ),
  Mastercourselist(
    title: "Fluidization Engineering",
    id: "CHE G511",
    credits: 4,
  ),

  Mastercourselist(
    title: "Petroleum Refining and Petrochemicals",
    id: "CHE G512",
    credits: 4,
  ),

  Mastercourselist(
    title: "Environmental Management Systems",
    id: "CHE G513",
    credits: 5,
  ),

  Mastercourselist(title: "Polymer Technology", id: "CHE G522", credits: 4),

  Mastercourselist(
    title: "Mathematical Methods in Chemical Engineering",
    id: "CHE G523",
    credits: 5,
  ),

  Mastercourselist(
    title: "Introduction to Multiphase flow",
    id: "CHE G524",
    credits: 4,
  ),

  Mastercourselist(title: "Nuclear Engineering", id: "CHE G526", credits: 4),

  Mastercourselist(
    title: "Energy Conservation and Management",
    id: "CHE G527",
    credits: 4,
  ),

  Mastercourselist(
    title: "Introduction to Nanoscience & Technology",
    id: "CHE G528",
    credits: 4,
  ),

  Mastercourselist(
    title: "Pulp & Paper Technology",
    id: "CHE G529",
    credits: 4,
  ),

  Mastercourselist(
    title: "Alternate Energy Resources",
    id: "CHE G532",
    credits: 4,
  ),

  Mastercourselist(
    title: "Petroleum Product Characterization",
    id: "CHE G533",
    credits: 5,
  ),

  Mastercourselist(
    title: "Advanced Separation Technology",
    id: "CHE G551",
    credits: 5,
  ),

  Mastercourselist(
    title: "Advanced Transport Phenomena",
    id: "CHE G552",
    credits: 5,
  ),

  Mastercourselist(
    title: "Computational Fluid Dynamics",
    id: "CHE G554",
    credits: 4,
  ),

  Mastercourselist(
    title: "Electrochemical Engineering",
    id: "CHE G556",
    credits: 4,
  ),

  Mastercourselist(
    title: "Energy Systems Engineering",
    id: "CHE G557",
    credits: 4,
  ),

  Mastercourselist(
    title: "Chemical Process Optimization",
    id: "CHE G558",
    credits: 4,
  ),

  Mastercourselist(
    title: "Modeling and Simulation in Petroleum Refining",
    id: "CHE G568",
    credits: 4,
  ),

  Mastercourselist(title: "Advanced Mass Transfer", id: "CHE G613", credits: 5),

  Mastercourselist(title: "Advanced Heat Transfer", id: "CHE G614", credits: 5),

  Mastercourselist(
    title: "Petroleum Reservoir Engineering",
    id: "CHE G616",
    credits: 5,
  ),

  Mastercourselist(
    title: "Petroleum Refinery Engg.",
    id: "CHE G617",
    credits: 5,
  ),

  Mastercourselist(
    title: "Petroleum Downstream Processing",
    id: "CHE G618",
    credits: 5,
  ),

  Mastercourselist(
    title: "Process Intensification",
    id: "CHE G619",
    credits: 5,
  ),

  Mastercourselist(
    title: "Energy Integration Analysis",
    id: "CHE G620",
    credits: 4,
  ),

  Mastercourselist(
    title: "Advanced Chemical Engineering Thermodynamics",
    id: "CHE G622",
    credits: 5,
  ),

  Mastercourselist(title: "Reaction Engineering", id: "CHE G641", credits: 5),

  //abcdef
  Mastercourselist(title: "Physical Chemistry I", id: "CHEM F211", credits: 3),
  Mastercourselist(title: "Organic Chemistry I", id: "CHEM F212", credits: 3),
  Mastercourselist(title: "Physical Chemistry II", id: "CHEM F213", credits: 3),
  Mastercourselist(title: "Inorganic Chemistry I", id: "CHEM F214", credits: 3),
  Mastercourselist(
    title: "Colloid and Surface Chemistry",
    id: "CHEM F223",
    credits: 3,
  ),
  Mastercourselist(
    title: "Inorganic Chemistry II",
    id: "CHEM F241",
    credits: 3,
  ),
  Mastercourselist(
    title: "Chemical Experimentation I",
    id: "CHEM F242",
    credits: 3,
  ),
  Mastercourselist(title: "Organic Chemistry II", id: "CHEM F243", credits: 3),
  Mastercourselist(
    title: "Physical Chemistry III",
    id: "CHEM F244",
    credits: 3,
  ),
  Mastercourselist(title: "Study Project", id: "CHEM F266", credits: 3),
  Mastercourselist(title: "Organic Chemistry III", id: "CHEM F311", credits: 3),
  Mastercourselist(title: "Physical Chemistry IV", id: "CHEM F312", credits: 3),
  Mastercourselist(
    title: "Instrumental Methods of Analysis",
    id: "CHEM F313",
    credits: 4,
  ),
  Mastercourselist(
    title: "Chemical Experimentation II",
    id: "CHEM F341",
    credits: 4,
  ),
  Mastercourselist(title: "Organic Chemistry IV", id: "CHEM F342", credits: 3),
  Mastercourselist(
    title: "Inorganic Chemistry III",
    id: "CHEM F343",
    credits: 3,
  ),
  Mastercourselist(title: "Lab Project", id: "CHEM F366", credits: 3),
  Mastercourselist(title: "Lab Project", id: "CHEM F367", credits: 3),
  Mastercourselist(title: "Design Project", id: "CHEM F376", credits: 3),
  Mastercourselist(title: "Design Project", id: "CHEM F377", credits: 3),
  Mastercourselist(
    title: "Colloid and Surface Chemistry",
    id: "CHEM F223",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introductory Computational Chemistry Laboratory",
    id: "CHEM F320",
    credits: 2,
  ),
  Mastercourselist(title: "Biophysical Chemistry", id: "CHEM F323", credits: 3),
  Mastercourselist(
    title: "Numerical Methods in Chemistry",
    id: "CHEM F324",
    credits: 4,
  ),
  Mastercourselist(title: "Polymer Chemistry", id: "CHEM F325", credits: 3),
  Mastercourselist(title: "Solid State Chemistry", id: "CHEM F326", credits: 3),
  Mastercourselist(
    title: "Electrochemistry: Fundamentals and Applications",
    id: "CHEM F327",
    credits: 3,
  ),
  Mastercourselist(
    title: "Supramolecular Chemistry",
    id: "CHEM F328",
    credits: 3,
  ),
  Mastercourselist(title: "Analytical Chemistry", id: "CHEM F329", credits: 4),
  Mastercourselist(
    title: "Photophysical Chemistry",
    id: "CHEM F330",
    credits: 4,
  ),
  Mastercourselist(
    title: "Chemistry of Materials",
    id: "CHEM F333",
    credits: 3,
  ),
  Mastercourselist(title: "Magnetic Resonance", id: "CHEM F334", credits: 3),
  Mastercourselist(
    title: "Organic Chemistry and Drug Design",
    id: "CHEM F335",
    credits: 3,
  ),
  Mastercourselist(title: "Nanochemistry", id: "CHEM F336", credits: 4),
  Mastercourselist(
    title: "Green Chemistry and Catalysis",
    id: "CHEM F337",
    credits: 3,
  ),
  Mastercourselist(
    title: "Photochemistry and Laser Spectroscopy",
    id: "CHEM F412",
    credits: 3,
  ),
  Mastercourselist(
    title: "Electron Correlation In Atoms And Molecules",
    id: "CHEM F413",
    credits: 4,
  ),
  Mastercourselist(
    title: "Bio and Chemical Sensors",
    id: "CHEM F414",
    credits: 3,
  ),
  Mastercourselist(
    title: "Frontiers in Organic Synthesis",
    id: "CHEM F415",
    credits: 3,
  ),
  Mastercourselist(
    title: "Applied Crystallography",
    id: "CHEM F416",
    credits: 3,
  ),
  Mastercourselist(
    title: "Statistical Thermodynamics",
    id: "CHEM F422",
    credits: 3,
  ),
  Mastercourselist(title: "Astrochemistry", id: "CHEM F423", credits: 3),
  Mastercourselist(title: "Atmospheric Chemistry", id: "CHEM F430", credits: 3),
  Mastercourselist(
    title: "Sustainable Chemistry using Renewables",
    id: "CHEM F431",
    credits: 3,
  ),
  Mastercourselist(title: "Special Projects", id: "CHEM F491", credits: 3),
  Mastercourselist(
    title: "Environmental Chemistry",
    id: "CHEM G521",
    credits: 5,
  ),

  //abcde
  Mastercourselist(title: "Modern Control Systems", id: "ECE F422", credits: 3),
  Mastercourselist(title: "Electrical Machines", id: "ECE F211", credits: 4),
  Mastercourselist(title: "Electromagnetic Theory", id: "ECE F212", credits: 3),
  Mastercourselist(title: "Electronic Devices", id: "ECE F214", credits: 3),
  Mastercourselist(title: "Digital Design", id: "ECE F215", credits: 4),
  Mastercourselist(
    title: "Microprocessors and Interfacing",
    id: "ECE F241",
    credits: 4,
  ),
  Mastercourselist(title: "Control Systems", id: "ECE F242", credits: 3),
  Mastercourselist(title: "Signals & Systems", id: "ECE F243", credits: 3),
  Mastercourselist(
    title: "Microelectronic Circuits",
    id: "ECE F244",
    credits: 3,
  ),
  Mastercourselist(title: "Analog Electronics", id: "ECE F341", credits: 4),
  Mastercourselist(title: "Study Project", id: "ECE F266", credits: 3),
  Mastercourselist(title: "Communication Systems", id: "ECE F311", credits: 4),
  Mastercourselist(
    title: "Electromagnetic Fields & Microwave Engineering",
    id: "ECE F314",
    credits: 4,
  ),
  Mastercourselist(title: "Communication Networks", id: "ECE F343", credits: 3),
  Mastercourselist(
    title: "Information Theory & Coding",
    id: "ECE F344",
    credits: 3,
  ),
  Mastercourselist(title: "Lab Project", id: "ECE F366", credits: 3),
  Mastercourselist(title: "Lab Project", id: "ECE F367", credits: 3),
  Mastercourselist(title: "Design Project", id: "ECE F376", credits: 3),
  Mastercourselist(title: "Design Project", id: "ECE F377", credits: 3),
  Mastercourselist(
    title: "Digital Signal Processing",
    id: "ECE F434",
    credits: 4,
  ),
  Mastercourselist(
    title: "Electronic Devices Simulation Laboratory",
    id: "ECE F216",
    credits: 2,
  ),
  Mastercourselist(
    title: "EM Fields and Microwave Engineering Laboratory",
    id: "ECE F312",
    credits: 1,
  ),
  Mastercourselist(
    title: "Telecommunication Switching Systems & Networks",
    id: "ECE F414",
    credits: 3,
  ),
  Mastercourselist(title: "Digital Communication", id: "ECE F416", credits: 3),
  Mastercourselist(
    title: "Modern Communication Technologies",
    id: "ECE F418",
    credits: 3,
  ),
  Mastercourselist(
    title: "Smart Grid for Sustainable Energy",
    id: "ECE F424",
    credits: 3,
  ),
  Mastercourselist(title: "Energy Storage Systems", id: "ECE F428", credits: 3),
  Mastercourselist(
    title: "Mobile Telecommunication Networks",
    id: "ECE F431",
    credits: 3,
  ),
  Mastercourselist(
    title: "Satellite Communication",
    id: "ECE F472",
    credits: 3,
  ),
  Mastercourselist(title: "Special Projects", id: "ECE F491", credits: 3),

  //abcdef
  Mastercourselist(
    title: "Principles of Economics",
    id: "ECON F211",
    credits: 3,
  ),
  Mastercourselist(
    title: "Fundamentals of Finance and Accounts",
    id: "ECON F212",
    credits: 3,
  ),
  Mastercourselist(
    title: "Mathematical and Statistical Methods",
    id: "ECON F213",
    credits: 3,
  ),
  Mastercourselist(
    title: "Economic Environment of Business",
    id: "ECON F214",
    credits: 3,
  ),
  Mastercourselist(title: "Econometric Methods", id: "ECON F241", credits: 3),
  Mastercourselist(title: "Microeconomics", id: "ECON F242", credits: 3),
  Mastercourselist(title: "Macroeconomics", id: "ECON F243", credits: 3),
  Mastercourselist(
    title: "Economics of Growth and Development",
    id: "ECON F244",
    credits: 3,
  ),
  Mastercourselist(title: "Study Project", id: "ECON F266", credits: 3),
  Mastercourselist(
    title: "International Economics",
    id: "ECON F311",
    credits: 3,
  ),
  Mastercourselist(
    title: "Money, Banking and Financial Markets",
    id: "ECON F312",
    credits: 3,
  ),
  Mastercourselist(
    title: "Issues in Economic Development",
    id: "ECON F313",
    credits: 3,
  ),
  Mastercourselist(
    title: "Public Finance Theory and Policy",
    id: "ECON F341",
    credits: 3,
  ),
  Mastercourselist(title: "Applied Econometrics", id: "ECON F342", credits: 3),
  Mastercourselist(
    title: "Economic Analysis of Public Policy",
    id: "ECON F343",
    credits: 3,
  ),
  Mastercourselist(
    title: "Models in Operations Management",
    id: "ECON F344",
    credits: 3,
  ),
  Mastercourselist(
    title: "Computational Methods for Economics",
    id: "ECON F215",
    credits: 3,
  ),
  Mastercourselist(title: "Financial Management", id: "ECON F315", credits: 3),
  Mastercourselist(title: "Industrial Economics", id: "ECON F314", credits: 3),
  Mastercourselist(title: "Behavioral Economics", id: "ECON F345", credits: 3),
  Mastercourselist(
    title: "Indian Economic Development",
    id: "ECON F351",
    credits: 3,
  ),
  Mastercourselist(
    title: "Management of Banks and Financial Institutions",
    id: "ECON F352",
    credits: 3,
  ),
  Mastercourselist(
    title: "Energy Economics and Policy",
    id: "ECON F353",
    credits: 3,
  ),
  Mastercourselist(
    title: "Derivatives and Risk Management",
    id: "ECON F354",
    credits: 3,
  ),
  Mastercourselist(
    title: "Business Analysis and Valuation",
    id: "ECON F355",
    credits: 3,
  ),
  Mastercourselist(
    title: "Strategic Financial Management",
    id: "ECON F356",
    credits: 3,
  ),
  Mastercourselist(
    title: "Management Control System",
    id: "ECON F357",
    credits: 3,
  ),
  Mastercourselist(title: "Lab Project", id: "ECON F366", credits: 3),
  Mastercourselist(title: "Lab Project", id: "ECON F367", credits: 3),
  Mastercourselist(title: "Project Appraisal", id: "ECON F411", credits: 3),
  Mastercourselist(
    title: "Security Analysis and Portfolio Management",
    id: "ECON F412",
    credits: 3,
  ),
  Mastercourselist(title: "Financial Engineering", id: "ECON F413", credits: 3),
  Mastercourselist(
    title: "Creating and Leading Entrepreneurial Organizations",
    id: "ECON F414",
    credits: 3,
  ),
  Mastercourselist(title: "New Venture Creation", id: "ECON F415", credits: 3),
  Mastercourselist(title: "Regional Economics", id: "ECON F416", credits: 3),
  Mastercourselist(
    title: "Risk Management and Insurance",
    id: "ECON F417",
    credits: 3,
  ),
  Mastercourselist(
    title: "Quantitative Analysis of International Trade",
    id: "ECON F418",
    credits: 3,
  ),
  Mastercourselist(
    title: "Advanced Microeconomics",
    id: "ECON F419",
    credits: 3,
  ),
  Mastercourselist(
    title: "Applied Macroeconometrics",
    id: "ECON F420",
    credits: 3,
  ),
  Mastercourselist(
    title: "Functions and Working of Stock Exchanges",
    id: "ECON F422",
    credits: 3,
  ),
  Mastercourselist(
    title: "International Business",
    id: "ECON F434",
    credits: 3,
  ),
  Mastercourselist(title: "Marketing Research", id: "ECON F435", credits: 3),
  Mastercourselist(
    title: "Resources and Environmental Economics",
    id: "ECON F471",
    credits: 3,
  ),
  Mastercourselist(title: "Special Projects", id: "ECON F491", credits: 3),

  //abcdef
  Mastercourselist(title: "Financial Management", id: "FIN F211", credits: 3),
  Mastercourselist(
    title: "Fundamentals of Finance and Accounts",
    id: "FIN F212",
    credits: 3,
  ),
  Mastercourselist(
    title: "Mathematical and Statistical Methods",
    id: "FIN F213",
    credits: 3,
  ),
  Mastercourselist(
    title: "Economic Environment of Business",
    id: "FIN F214",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Financial Mathematics",
    id: "FIN F242",
    credits: 3,
  ),
  Mastercourselist(
    title: "Functions and Working of Stock Exchanges",
    id: "FIN F243",
    credits: 3,
  ),
  Mastercourselist(
    title: "Indian Financial System",
    id: "FIN F244",
    credits: 3,
  ),
  Mastercourselist(title: "Study Project", id: "FIN F266", credits: 3),
  Mastercourselist(
    title: "Derivatives and Risk Management",
    id: "FIN F311",
    credits: 3,
  ),
  Mastercourselist(
    title: "Fundamental of Taxation and Audit",
    id: "FIN F312",
    credits: 3,
  ),
  Mastercourselist(
    title: "Security Analysis and Portfolio Management",
    id: "FIN F313",
    credits: 3,
  ),
  Mastercourselist(
    title: "Investment Banking and Financial Services",
    id: "FIN F314",
    credits: 3,
  ),
  Mastercourselist(title: "Financial Management", id: "FIN F315", credits: 3),
  Mastercourselist(
    title: "International Financial Markets and Services",
    id: "FIN F341",
    credits: 3,
  ),
  Mastercourselist(title: "Project Finance", id: "FIN F342", credits: 3),
  Mastercourselist(title: "Lab Project", id: "FIN F366", credits: 3),
  Mastercourselist(title: "Lab Project", id: "FIN F367", credits: 3),
  Mastercourselist(
    title: "Financial Risk Analytics and Risk Management",
    id: "FIN F414",
    credits: 3,
  ),
  Mastercourselist(title: "Special Projects", id: "FIN F491", credits: 3),

  // abcdef
  Mastercourselist(
    title: "Modern Political Concepts",
    id: "GS F211",
    credits: 3,
  ),
  Mastercourselist(
    title: "Environment, Development & Climate Change",
    id: "GS F212",
    credits: 3,
  ),
  Mastercourselist(title: "Development Theories", id: "GS F213", credits: 3),
  Mastercourselist(title: "Business Communication", id: "GS F221", credits: 3),
  Mastercourselist(title: "Language Lab Practice", id: "GS F222", credits: 3),
  Mastercourselist(
    title: "Introduction to Mass Communication",
    id: "GS F223",
    credits: 3,
  ),
  Mastercourselist(
    title: "Print and Audio Visual Advertising",
    id: "GS F224",
    credits: 3,
  ),
  Mastercourselist(
    title: "Dynamics of Social Change",
    id: "GS F231",
    credits: 3,
  ),
  Mastercourselist(title: "Introductory Psychology", id: "GS F232", credits: 3),
  Mastercourselist(title: "Public Policy", id: "GS F233", credits: 3),
  Mastercourselist(title: "Development Economics", id: "GS F234", credits: 3),
  Mastercourselist(title: "Creative Writing", id: "GS F241", credits: 3),
  Mastercourselist(title: "Cultural Studies", id: "GS F242", credits: 3),
  Mastercourselist(title: "Current Affairs", id: "GS F243", credits: 3),
  Mastercourselist(
    title: "Reporting and Writing for Media",
    id: "GS F244",
    credits: 3,
  ),
  Mastercourselist(
    title: "Effective Public Speaking",
    id: "GS F245",
    credits: 3,
  ),
  Mastercourselist(title: "Study Project", id: "GS F266", credits: 3),
  Mastercourselist(
    title: "Mass Media Content and Design",
    id: "GS F321",
    credits: 3,
  ),
  Mastercourselist(
    title: "Critical Analysis of Literature and Cinema",
    id: "GS F322",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Conflict Management",
    id: "GS F311",
    credits: 3,
  ),
  Mastercourselist(title: "Applied Philosophy", id: "GS F312", credits: 3),
  Mastercourselist(title: "Marxian Thoughts", id: "GS F313", credits: 3),
  Mastercourselist(title: "Journalism", id: "GS F325", credits: 3),
  Mastercourselist(title: "Creative Thinking", id: "GS F326", credits: 3),
  Mastercourselist(title: "Selected Reading", id: "GS F327", credits: 3),
  Mastercourselist(
    title: "Techniques in Social Research",
    id: "GS F331",
    credits: 3,
  ),
  Mastercourselist(title: "Contemporary India", id: "GS F332", credits: 3),
  Mastercourselist(title: "Public Administration", id: "GS F333", credits: 3),
  Mastercourselist(
    title: "Global Business Technology & Knowledge Sharing",
    id: "GS F334",
    credits: 3,
  ),
  Mastercourselist(
    title: "Computer Mediator Communication",
    id: "EEE F342",
    credits: 3,
  ),
  Mastercourselist(
    title: "Short Film and Video Production",
    id: "GS F343",
    credits: 3,
  ),
  Mastercourselist(title: "Copywriting", id: "GS F344", credits: 2),
  Mastercourselist(title: "Lab Project", id: "GS F366", credits: 3),
  Mastercourselist(title: "Lab Project", id: "GS F367", credits: 3),
  Mastercourselist(title: "Special Projects", id: "GS F491", credits: 3),

  //abcdef
  Mastercourselist(title: "Readings from Drama", id: "HSS F221", credits: 3),
  Mastercourselist(title: "Linguistics", id: "HSS F222", credits: 3),
  Mastercourselist(
    title: "Appreciation of Indian Music",
    id: "HSS F223",
    credits: 3,
  ),
  Mastercourselist(title: "Postmodernism", id: "HSS F226", credits: 3),
  Mastercourselist(title: "Cross Cultural Skills", id: "HSS F227", credits: 3),
  Mastercourselist(
    title: "Phonetics and Spoken English",
    id: "HSS F228",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Development Studies",
    id: "HSS F229",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Development Studies",
    id: "HSS F232",
    credits: 3,
  ),
  Mastercourselist(
    title: "Main Trends in Indian History",
    id: "HSS F233",
    credits: 3,
  ),
  Mastercourselist(
    title: "Main Currents of Modern History",
    id: "HSS F234",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introductory Philosophy",
    id: "HSS F235",
    credits: 3,
  ),
  Mastercourselist(title: "Symbolic Logic", id: "HSS F236", credits: 3),
  Mastercourselist(
    title: "Contemporary Indian English Fiction",
    id: "HSS F237",
    credits: 3,
  ),
  Mastercourselist(title: "Sports and Society", id: "HSS F238", credits: 3),
  Mastercourselist(
    title: "Introduction to Phonology",
    id: "HSS F242",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Pedalogy",
    id: "HSS F243",
    credits: 3,
  ),
  Mastercourselist(title: "Crime and New Media", id: "HSS F244", credits: 3),
  Mastercourselist(
    title: "Gender, Science and Technology",
    id: "HSS F245",
    credits: 3,
  ),
  Mastercourselist(
    title: "Philosophy of Nāgārjuna",
    id: "HSS F246",
    credits: 3,
  ),
  Mastercourselist(title: "Social Informatics", id: "HSS F247", credits: 3),
  Mastercourselist(
    title: "Introduction to Disability Studies",
    id: "HSS F248",
    credits: 3,
  ),
  Mastercourselist(title: "Politics in India", id: "HSS F249", credits: 3),
  Mastercourselist(
    title: "Comics and Visual Culture",
    id: "HSS F250",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Discourse and Conversational Analysis",
    id: "HSS F251",
    credits: 3,
  ),
  Mastercourselist(title: "International Law", id: "HSS F252", credits: 3),
  Mastercourselist(title: "Study Project", id: "HSS F266", credits: 3),
  Mastercourselist(
    title: "Introduction to Videogame Studies",
    id: "HSS F311",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Contemporary Arts",
    id: "HSS F313",
    credits: 3,
  ),
  Mastercourselist(
    title: "Society, Business, and Politics",
    id: "HSS F315",
    credits: 3,
  ),
  Mastercourselist(
    title: "Popular Literature and Culture of South Asia",
    id: "HSS F316",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Globalization",
    id: "HSS F317",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Anthropology",
    id: "HSS F318",
    credits: 3,
  ),
  Mastercourselist(
    title: "Lighting for Theatre and Films",
    id: "HSS F319",
    credits: 2,
  ),
  Mastercourselist(
    title: "Social and Political Ecology",
    id: "HSS F322",
    credits: 3,
  ),
  Mastercourselist(
    title: "Organizational Psychology",
    id: "HSS F323",
    credits: 3,
  ),
  Mastercourselist(title: "Cinematic Adaptation", id: "HSS F325", credits: 3),
  Mastercourselist(title: "Humanities and Design", id: "HSS F326", credits: 3),
  Mastercourselist(title: "Contemporary Drama", id: "HSS F327", credits: 3),
  Mastercourselist(
    title: "Human Resource Development",
    id: "HSS F328",
    credits: 3,
  ),
  Mastercourselist(
    title: "Musicology – An – Introduction",
    id: "HSS F329",
    credits: 3,
  ),
  Mastercourselist(title: "Appreciation of Art", id: "HSS F330", credits: 3),
  Mastercourselist(title: "Sankara’s Thoughts", id: "HSS F331", credits: 3),
  Mastercourselist(title: "Cinematic Art", id: "HSS F332", credits: 3),
  Mastercourselist(title: "Comparative Religion", id: "HSS F333", credits: 3),
  Mastercourselist(title: "Srimad Bhagavad Gita", id: "HSS F334", credits: 3),
  Mastercourselist(title: "Literary Criticism", id: "HSS F335", credits: 3),
  Mastercourselist(title: "Modern Fiction", id: "HSS F336", credits: 3),
  Mastercourselist(
    title: "English Literary Forms and Movements",
    id: "HSS F337",
    credits: 3,
  ),
  Mastercourselist(
    title: "Comparative Indian Literature",
    id: "HSS F338",
    credits: 3,
  ),
  Mastercourselist(
    title: "Theatre Art Acting and Production",
    id: "HSS F339",
    credits: 3,
  ),
  Mastercourselist(
    title: "Post Colonial Literatures",
    id: "HSS F340",
    credits: 3,
  ),
  Mastercourselist(title: "Performance Design", id: "HSS F341", credits: 3),
  Mastercourselist(
    title: "Advanced Communicative English",
    id: "HSS F342",
    credits: 3,
  ),
  Mastercourselist(title: "Professional Ethics", id: "HSS F343", credits: 3),
  Mastercourselist(title: "Heritage of India", id: "HSS F344", credits: 3),
  Mastercourselist(title: "Gandhian Thoughts", id: "HSS F345", credits: 3),
  Mastercourselist(
    title: "International Relations",
    id: "HSS F346",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Carnatic Music",
    id: "HSS F347",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Hindustani Music",
    id: "HSS F348",
    credits: 3,
  ),
  Mastercourselist(title: "Ecocriticism", id: "HSS F349", credits: 3),
  Mastercourselist(
    title: "Human Rights: History, Theory & Practice",
    id: "HSS F350",
    credits: 3,
  ),
  Mastercourselist(
    title: "Social and Political Ecology",
    id: "HSS F351",
    credits: 3,
  ),
  Mastercourselist(
    title: "Technology, Work and Society",
    id: "HSS F352",
    credits: 3,
  ),
  Mastercourselist(
    title: "Philosophy of Aesthetics",
    id: "HSS F353",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Islamic Economy",
    id: "HSS F354",
    credits: 3,
  ),
  Mastercourselist(
    title: "Dictatorship, Democracy & Development",
    id: "HSS F355",
    credits: 3,
  ),
  Mastercourselist(
    title: "Social Movements and Protest Politics",
    id: "HSS F356",
    credits: 3,
  ),
  Mastercourselist(
    title: "Urban Policy and Governance",
    id: "HSS F361",
    credits: 3,
  ),
  Mastercourselist(
    title: "Local Governance and Participation",
    id: "HSS F362",
    credits: 3,
  ),
  Mastercourselist(
    title: "Disaster and Development",
    id: "HSS F363",
    credits: 3,
  ),
  Mastercourselist(
    title: "Political Economy of Gulf Cooperation Council States",
    id: "HSS F364",
    credits: 3,
  ),
  Mastercourselist(
    title: "Science of Sustainable Happiness",
    id: "HSS F365",
    credits: 3,
  ),
  Mastercourselist(
    title: "Asian Cinemas and Cultures",
    id: "HSS F368",
    credits: 3,
  ),
  Mastercourselist(
    title: "Caste and Gender in India",
    id: "HSS F369",
    credits: 3,
  ),
  Mastercourselist(
    title: "Cities-Life, Issues and Conflicts",
    id: "HSS F371",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Social Psychology",
    id: "HSS F372",
    credits: 3,
  ),
  Mastercourselist(
    title: "Shakespeare and Popular Culture",
    id: "HSS F373",
    credits: 3,
  ),
  Mastercourselist(
    title: "Urban Modernity and the Renewal of Paris",
    id: "HSS F374",
    credits: 3,
  ),
  Mastercourselist(
    title:
        "Business and Politics in Colonial and Post Colonial India: a historical approach",
    id: "HSS F375",
    credits: 3,
  ),
  Mastercourselist(
    title: "Cinemas of India: From Past to Present",
    id: "HSS F378",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to American Literature",
    id: "HSS F399",
    credits: 3,
  ),

  //abcdef
  Mastercourselist(title: "Electrical Machines", id: "INSTR F211", credits: 4),
  Mastercourselist(
    title: "Electromagnetic Theory",
    id: "INSTR F212",
    credits: 3,
  ),
  Mastercourselist(title: "Electronic Devices", id: "INSTR F214", credits: 3),
  Mastercourselist(title: "Digital Design", id: "INSTR F215", credits: 4),
  Mastercourselist(
    title: "Microprocessors and Interfacing",
    id: "INSTR F241",
    credits: 4,
  ),
  Mastercourselist(title: "Control Systems", id: "INSTR F242", credits: 3),
  Mastercourselist(title: "Signals & Systems", id: "INSTR F243", credits: 3),
  Mastercourselist(
    title: "Microelectronic Circuits",
    id: "INSTR F244",
    credits: 3,
  ),
  Mastercourselist(title: "Study Project", id: "INSTR F266", credits: 3),
  Mastercourselist(
    title: "Electronic Instrumentation & Instrumentation Technology",
    id: "INSTR F311",
    credits: 4,
  ),
  Mastercourselist(
    title: "Transducers and Measurement Systems",
    id: "INSTR F312",
    credits: 3,
  ),
  Mastercourselist(
    title: "Analog & Digital VLSI Design",
    id: "INSTR F313",
    credits: 3,
  ),
  Mastercourselist(title: "Analog Electronics", id: "INSTR F341", credits: 4),
  Mastercourselist(title: "Power Electronics", id: "INSTR F342", credits: 4),
  Mastercourselist(
    title: "Industrial Instrumentation & Control",
    id: "INSTR F343",
    credits: 3,
  ),
  Mastercourselist(title: "Lab Project", id: "INSTR F366", credits: 3),
  Mastercourselist(title: "Lab Project", id: "INSTR F367", credits: 3),
  Mastercourselist(title: "Design Project", id: "INSTR F376", credits: 3),
  Mastercourselist(title: "Design Project", id: "INSTR F376", credits: 3),
  Mastercourselist(
    title: "Electronic Devices Simulation Laboratory",
    id: "INSTR F216",
    credits: 2,
  ),
  Mastercourselist(
    title: "Opto-Electronic Instruments",
    id: "INSTR F411",
    credits: 3,
  ),
  Mastercourselist(
    title: "Analysis Instrumentation",
    id: "INSTR F412",
    credits: 3,
  ),
  Mastercourselist(
    title: "Advanced Process Control",
    id: "INSTR F413",
    credits: 3,
  ),
  Mastercourselist(
    title: "Telecommunication Switching Systems & Networks",
    id: "INSTR F414",
    credits: 3,
  ),
  Mastercourselist(title: "Digital Control", id: "INSTR F415", credits: 3),
  Mastercourselist(
    title: "Virtual Instrumentation",
    id: "INSTR F419",
    credits: 4,
  ),
  Mastercourselist(
    title: "Design of Instrumentation Systems",
    id: "INSTR F420",
    credits: 3,
  ),
  Mastercourselist(
    title: "Instrumentation for Petrochemical Industry",
    id: "INSTR F422",
    credits: 3,
  ),
  Mastercourselist(
    title: "Smart Grid for Sustainable Energy",
    id: "INSTR F424",
    credits: 3,
  ),
  Mastercourselist(
    title: "Energy Storage Systems",
    id: "INSTR F428",
    credits: 3,
  ),
  Mastercourselist(
    title: "Smart Materials and Applications",
    id: "INSTR F429",
    credits: 4,
  ),
  Mastercourselist(
    title: "Green Communications and Networks",
    id: "INSTR F430",
    credits: 3,
  ),
  Mastercourselist(
    title: "Medical Instrumentation",
    id: "INSTR F432",
    credits: 3,
  ),
  Mastercourselist(
    title: "Wind Electrical Systems",
    id: "INSTR F473",
    credits: 3,
  ),
  Mastercourselist(title: "Special Projects", id: "INSTR F491", credits: 3),
  Mastercourselist(
    title: "Advanced Control Systems",
    id: "INSTR G611",
    credits: 5,
  ),

  //abcedf
  Mastercourselist(
    title: "Data Structures and Algorithms",
    id: "IS F211",
    credits: 4,
  ),

  Mastercourselist(
    title: "Object Oriented Programming",
    id: "IS F213",
    credits: 4,
  ),

  Mastercourselist(
    title: "Logic in Computer Science",
    id: "IS F214",
    credits: 3,
  ),

  Mastercourselist(
    title: "Discrete Structures for Computer Science",
    id: "IS F222",
    credits: 3,
  ),

  Mastercourselist(
    title: "Digital Electronics and Microprocessors",
    id: "IS F241",
    credits: 4,
  ),

  Mastercourselist(title: "Computer Organization", id: "IS F242", credits: 4),

  Mastercourselist(
    title: "Database System and Application",
    id: "IS F243",
    credits: 4,
  ),

  Mastercourselist(title: "Study Project", id: "IS F266", credits: 3),

  Mastercourselist(
    title: "Principles of Programming",
    id: "IS F301",
    credits: 2,
  ),

  Mastercourselist(title: "Computer Networks", id: "IS F303", credits: 4),

  Mastercourselist(title: "Computer Graphics", id: "IS F311", credits: 3),

  Mastercourselist(title: "Software Testing", id: "IS F322", credits: 3),

  Mastercourselist(title: "Software Engineering", id: "IS F341", credits: 4),

  Mastercourselist(title: "Compiler Design", id: "IS F342", credits: 3),

  Mastercourselist(title: "Lab Project", id: "IS F366", credits: 3),

  Mastercourselist(title: "Lab Project", id: "IS F367", credits: 3),

  Mastercourselist(title: "Design Project", id: "IS F376", credits: 3),

  Mastercourselist(title: "Design Project", id: "IS F377", credits: 3),

  Mastercourselist(title: "Operating Systems", id: "IS F372", credits: 3),

  Mastercourselist(title: "Network Programming", id: "IS F462", credits: 3),

  Mastercourselist(title: "Special Project", id: "IS F491", credits: 3),

  //abcedf
  Mastercourselist(
    title: "Linear Algebra and Applications",
    id: "MAC F211",
    credits: 3,
  ),
  Mastercourselist(
    title: "Object Oriented Programming",
    id: "MAC F212",
    credits: 4,
  ),
  Mastercourselist(title: "Discrete Mathematics", id: "MAC F213", credits: 3),
  Mastercourselist(
    title: "Elementary Real Analysis",
    id: "MAC F214",
    credits: 3,
  ),
  Mastercourselist(title: "Numerical Analysis", id: "MAC F241", credits: 4),
  Mastercourselist(
    title: "Data Structures & Algorithms",
    id: "MAC F242",
    credits: 3,
  ),
  Mastercourselist(title: "Numerical Optimization", id: "MAC F243", credits: 3),
  Mastercourselist(
    title: "Stochastic Calculus and Application to Finance",
    id: "MAC F244",
    credits: 3,
  ),
  Mastercourselist(
    title: "Scientific Computing Laboratory",
    id: "MAC F245",
    credits: 1,
  ),
  Mastercourselist(title: "Algebra I", id: "MAC F311", credits: 3),
  Mastercourselist(
    title: "Foundations of Data Science",
    id: "MAC F312",
    credits: 3,
  ),
  Mastercourselist(
    title: "Statistical Data Analysis",
    id: "MAC F313",
    credits: 4,
  ),
  Mastercourselist(title: "Mathematical Modelling", id: "MAC F314", credits: 4),
  Mastercourselist(
    title: "Design and Analysis of Algorithms",
    id: "MAC F341",
    credits: 3,
  ),
  Mastercourselist(
    title: "Computations Partial Differential Equations",
    id: "MAC F342",
    credits: 4,
  ),

  //abcedf
  Mastercourselist(title: "Mathematics III", id: "MATH F211", credits: 3),
  Mastercourselist(title: "Optimization", id: "MATH F212", credits: 3),
  Mastercourselist(title: "Discrete Mathematics", id: "MATH F213", credits: 3),
  Mastercourselist(
    title: "Elementary Real Analysis",
    id: "MATH F214",
    credits: 3,
  ),
  Mastercourselist(title: "Algebra I", id: "MATH F215", credits: 3),
  Mastercourselist(title: "Mathematical Methods", id: "MATH F241", credits: 3),
  Mastercourselist(title: "Operations Research", id: "MATH F242", credits: 3),
  Mastercourselist(title: "Graphs and Networks", id: "MATH F243", credits: 3),
  Mastercourselist(title: "Measure & Integration", id: "MATH F244", credits: 3),
  Mastercourselist(title: "Study Project", id: "MATH F266", credits: 3),
  Mastercourselist(
    title: "Introduction to Topology",
    id: "MATH F311",
    credits: 3,
  ),
  Mastercourselist(
    title: "Ordinary Differential Equations",
    id: "MATH F312",
    credits: 3,
  ),
  Mastercourselist(title: "Numerical Analysis", id: "MATH F313", credits: 3),
  Mastercourselist(title: "Algebra II", id: "MATH F314", credits: 3),
  Mastercourselist(
    title: "Introduction to Functional Analysis",
    id: "MATH F341",
    credits: 3,
  ),
  Mastercourselist(title: "Differential Geometry", id: "MATH F342", credits: 3),
  Mastercourselist(
    title: "Partial Differential Equations",
    id: "MATH F343",
    credits: 3,
  ),
  Mastercourselist(
    title: "Mathematical Fluid Dynamics",
    id: "MATH F344",
    credits: 3,
  ),
  Mastercourselist(title: "Number Theory", id: "MATH F231", credits: 3),
  Mastercourselist(title: "Algebra II", id: "MATH F314", credits: 3),
  Mastercourselist(
    title: "Introduction to Statistical Inference",
    id: "MATH F315",
    credits: 3,
  ),
  Mastercourselist(
    title: "Matrix Theory and Linear Estimation",
    id: "MATH F316",
    credits: 4,
  ),
  Mastercourselist(title: "Sampling Theory", id: "MATH F317", credits: 4),
  Mastercourselist(
    title: "Statistical Inference and Applications",
    id: "MATH F353",
    credits: 3,
  ),
  Mastercourselist(title: "Complex Analysis", id: "MATH F354", credits: 3),
  Mastercourselist(title: "Lab Project", id: "MATH F366", credits: 3),
  Mastercourselist(title: "Lab Project", id: "MATH F367", credits: 3),
  Mastercourselist(title: "Design Project", id: "MATH F376", credits: 3),
  Mastercourselist(title: "Deisgn Project", id: "MATH F377", credits: 3),
  Mastercourselist(
    title: "Advanced Probability Theory",
    id: "MATH F378",
    credits: 3,
  ),
  Mastercourselist(title: "Mathematical Modeling", id: "MATH F420", credits: 4),
  Mastercourselist(
    title: "Combinatorial Mathematics",
    id: "MATH F421",
    credits: 3,
  ),
  Mastercourselist(
    title: "Numerical Methodology for Partial Differential Equations",
    id: "MATH F422",
    credits: 4,
  ),
  Mastercourselist(
    title: "Introduction to Algebraic Topology",
    id: "MATH F423",
    credits: 3,
  ),
  Mastercourselist(
    title: "Applied Stochastic Process",
    id: "MATH F424",
    credits: 4,
  ),
  Mastercourselist(
    title: "Numerical Linear Algebra",
    id: "MATH F425",
    credits: 4,
  ),
  Mastercourselist(
    title: "Mathematical Theory of Finite Element Methods",
    id: "MATH F426",
    credits: 4,
  ),
  Mastercourselist(
    title: "Statistical Simulation and Data Analysis",
    id: "MATH F427",
    credits: 4,
  ),
  Mastercourselist(
    title: "Time Series Analysis and Forecasting",
    id: "MATH F428",
    credits: 4,
  ),
  Mastercourselist(title: "Distribution Theory", id: "MATH F431", credits: 3),
  Mastercourselist(
    title: "Applied Statistical Methods",
    id: "MATH F432",
    credits: 3,
  ),
  Mastercourselist(
    title: "Discrete Mathematical Structures",
    id: "MATH F441",
    credits: 3,
  ),
  Mastercourselist(
    title: "Numerical Solutions of Ordinary Differential Equations",
    id: "MATH F444",
    credits: 3,
  ),
  Mastercourselist(
    title: "Mathematical Fluid Dynamics",
    id: "MATH F445",
    credits: 3,
  ),
  Mastercourselist(title: "Cosmology", id: "MATH F456", credits: 3),
  Mastercourselist(
    title: "Nonlinear Optimization",
    id: "MATH F471",
    credits: 3,
  ),
  Mastercourselist(title: "Commutative Algebra", id: "MATH F481", credits: 3),
  Mastercourselist(title: "Special Projects", id: "MATH F491", credits: 3),
  Mastercourselist(
    title: "Wavelet Analysis and Applications",
    id: "MATH F492",
    credits: 4,
  ),

  //abcdef
  Mastercourselist(title: "Mechanics of Solids", id: "ME F211", credits: 3),
  Mastercourselist(title: "Fluid Mechanics", id: "ME F212", credits: 3),
  Mastercourselist(
    title: "Material Science and Engineering",
    id: "ME F213",
    credits: 2,
  ),
  Mastercourselist(title: "Applied Thermodynamics", id: "ME F214", credits: 3),
  Mastercourselist(
    title: "Mechanical Engineering Laboratory",
    id: "ME F215",
    credits: 2,
  ),
  Mastercourselist(
    title: "Materials Science and Engineering",
    id: "ME F216",
    credits: 3,
  ),
  Mastercourselist(title: "Applied Thermodynamics", id: "ME F217", credits: 4),
  Mastercourselist(
    title: "Advanced Mechanics of Solids",
    id: "ME F218",
    credits: 2,
  ),
  Mastercourselist(title: "Manufacturing Processes", id: "ME F219", credits: 4),
  Mastercourselist(title: "Heat Transfer", id: "ME F220", credits: 4),
  Mastercourselist(title: "Mechanisms and Machines", id: "ME F221", credits: 3),
  Mastercourselist(
    title: "Machine Design and Drawing",
    id: "ME F241",
    credits: 4,
  ),
  Mastercourselist(title: "IC Engines", id: "ME F242", credits: 2),
  Mastercourselist(title: "Production Techniques I", id: "ME F243", credits: 3),
  Mastercourselist(
    title: "Kinematics and Dynamics of Machinery",
    id: "ME F244",
    credits: 3,
  ),
  Mastercourselist(title: "Study Projects", id: "ME F266", credits: 3),
  Mastercourselist(title: "Heat Transfer", id: "ME F311", credits: 4),
  Mastercourselist(
    title: "Advanced Mechanics of Solids",
    id: "ME F312",
    credits: 3,
  ),
  Mastercourselist(
    title: "Production Techniques II",
    id: "ME F313",
    credits: 4,
  ),
  Mastercourselist(
    title: "Design of Machine Elements",
    id: "ME F314",
    credits: 3,
  ),
  Mastercourselist(
    title: "Advanced Manufacturing Processes",
    id: "ME F315",
    credits: 3,
  ),
  Mastercourselist(
    title: "Manufacturing Management",
    id: "ME F316",
    credits: 2,
  ),
  Mastercourselist(
    title: "Engines, Motors, and Mobility",
    id: "ME F317",
    credits: 2,
  ),
  Mastercourselist(title: "Computer-Aided Design", id: "ME F318", credits: 3),
  Mastercourselist(title: "Vibrations and Control", id: "ME F319", credits: 3),
  Mastercourselist(
    title: "Engineering Optimization",
    id: "ME F320",
    credits: 3,
  ),
  Mastercourselist(
    title: "Prime Movers & Fluid Machines",
    id: "ME F341",
    credits: 3,
  ),
  Mastercourselist(title: "Computer Aided Design", id: "ME F342", credits: 4),
  Mastercourselist(title: "Mechanical Vibrations", id: "ME F343", credits: 3),
  Mastercourselist(
    title: "Engineering Optimization",
    id: "ME F344",
    credits: 2,
  ),
  Mastercourselist(title: "Lab Project", id: "ME F367", credits: 3),
  Mastercourselist(title: "Lab Project", id: "ME F366", credits: 3),
  Mastercourselist(title: "Design Project", id: "ME F376", credits: 3),
  Mastercourselist(title: "Design Project", id: "ME F377", credits: 3),
  Mastercourselist(
    title: "Data Mining in Mechanical Sciences",
    id: "ME F321",
    credits: 3,
  ),
  Mastercourselist(
    title: "Energy Storage Technologies",
    id: "ME F323",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Sports Engineering",
    id: "ME F340",
    credits: 3,
  ),
  Mastercourselist(title: "Fluid Power Systems", id: "ME F411", credits: 4),
  Mastercourselist(
    title: "Production Planning and Control",
    id: "ME F412",
    credits: 3,
  ),
  Mastercourselist(title: "Nonlinear Vibrations", id: "ME F413", credits: 3),
  Mastercourselist(
    title: "Fuel Cell Science and Technology",
    id: "ME F414",
    credits: 3,
  ),
  Mastercourselist(title: "Gas Dynamics", id: "ME F415", credits: 3),
  Mastercourselist(
    title: "Reverse Engineering and Rapid Prototyping",
    id: "ME F416",
    credits: 3,
  ),
  Mastercourselist(title: "Advanced Metal Forming", id: "ME F417", credits: 3),
  Mastercourselist(
    title: "Rocket and Spacecraft Propulsion",
    id: "ME F418",
    credits: 3,
  ),
  Mastercourselist(
    title: "Total Product Integration Engg.",
    id: "ME F419",
    credits: 3,
  ),
  Mastercourselist(title: "Power Plant Engineering", id: "ME F420", credits: 3),
  Mastercourselist(
    title: "Microfluidics and Applications",
    id: "ME F423",
    credits: 4,
  ),
  Mastercourselist(title: "Energy Management", id: "ME F424", credits: 3),
  Mastercourselist(title: "Additive Manufacturing", id: "ME F425", credits: 3),
  Mastercourselist(
    title: "Industry 4.0 in Manufacturing",
    id: "ME F426",
    credits: 3,
  ),
  Mastercourselist(title: "Continuum Mechanics", id: "ME F427", credits: 4),
  Mastercourselist(title: "Smart Materials", id: "ME F428", credits: 4),
  Mastercourselist(
    title: "Micro-Nanoscale Heat Transport",
    id: "ME F429",
    credits: 4,
  ),
  Mastercourselist(
    title: "Computer Aided Manufacturing",
    id: "ME F432",
    credits: 3,
  ),
  Mastercourselist(
    title: "Solar Thermal Process Engineering",
    id: "ME F433",
    credits: 4,
  ),
  Mastercourselist(title: "Automotive Vehicles", id: "ME F441", credits: 3),
  Mastercourselist(
    title: "Quality Control, Assurance and Reliability",
    id: "ME F443",
    credits: 3,
  ),
  Mastercourselist(
    title: "Mechanical Equipment Design",
    id: "ME F451",
    credits: 3,
  ),
  Mastercourselist(
    title: "Composite Materials & Design",
    id: "ME F452",
    credits: 3,
  ),
  Mastercourselist(
    title: "Refrigeration and Air Conditioning",
    id: "ME F461",
    credits: 3,
  ),
  Mastercourselist(title: "Precision Engineering", id: "ME F472", credits: 3),
  Mastercourselist(title: "Project Appraisal", id: "ME F481", credits: 3),
  Mastercourselist(title: "Combustion", id: "ME F482", credits: 3),
  Mastercourselist(title: "Wind Energy", id: "ME F483", credits: 3),
  Mastercourselist(title: "Automotive Technology", id: "ME F484", credits: 3),
  Mastercourselist(
    title: "Numerical Techniques for Fluid Flow and Heat Transfer",
    id: "ME F485",
    credits: 3,
  ),
  Mastercourselist(title: "Special Projects", id: "ME F491", credits: 3),
  Mastercourselist(title: "Finite Element Methods", id: "ME G512", credits: 5),
  Mastercourselist(title: "Turbo Machinery", id: "ME G514", credits: 5),
  Mastercourselist(
    title: "Computational Fluid Dynamics",
    id: "ME G515",
    credits: 5,
  ),

  //abcdef
  Mastercourselist(title: "Mechanics of Solids", id: "MF F211", credits: 3),
  Mastercourselist(title: "Fluid Mechanics", id: "MF F212", credits: 3),
  Mastercourselist(
    title: "Material Science and Engineering",
    id: "MF F213",
    credits: 2,
  ),
  Mastercourselist(title: "Applied Thermodynamics", id: "MF F214", credits: 3),
  Mastercourselist(
    title: "Mechanical Engineering Laboratory",
    id: "MF F215",
    credits: 2,
  ),
  Mastercourselist(
    title: "Materials Science and Engineering",
    id: "MF F216",
    credits: 3,
  ),
  Mastercourselist(title: "Machine Drawing", id: "MF F217", credits: 2),
  Mastercourselist(
    title: "Transport Phenomena in Manufacturing",
    id: "MF F218",
    credits: 4,
  ),
  Mastercourselist(title: "Operations Management", id: "MF F219", credits: 3),
  Mastercourselist(
    title: "Metrology and Quality Assurance",
    id: "MF F220",
    credits: 3,
  ),
  Mastercourselist(title: "Mechanisms and Machines", id: "MF F221", credits: 3),
  Mastercourselist(
    title: "Casting, Forming and Welding",
    id: "MF F222",
    credits: 4,
  ),
  Mastercourselist(
    title: "Machine Design and Drawing",
    id: "MF F241",
    credits: 4,
  ),
  Mastercourselist(
    title: "Manufacturing Management",
    id: "MF F242",
    credits: 2,
  ),
  Mastercourselist(title: "Manufacturing Processes", id: "MF F243", credits: 3),
  Mastercourselist(
    title: "Kinematics and Dynamics of Machinery",
    id: "MF F244",
    credits: 3,
  ),
  Mastercourselist(title: "Study Project", id: "MF F266", credits: 3),
  Mastercourselist(
    title: "Mechatronics and Automation",
    id: "MF F311",
    credits: 3,
  ),
  Mastercourselist(title: "Tool and Fixture Design", id: "MF F312", credits: 3),
  Mastercourselist(
    title: "Metal Forming and Machining",
    id: "MF F313",
    credits: 3,
  ),
  Mastercourselist(
    title: "Design of Machine Elements",
    id: "MF F314",
    credits: 3,
  ),
  Mastercourselist(title: "Automation and Control", id: "MF F315", credits: 4),
  Mastercourselist(
    title: "Machining and Machine Tools",
    id: "MF F316",
    credits: 4,
  ),
  Mastercourselist(
    title: "Computer Aided Design and Manufacturing",
    id: "MF F317",
    credits: 3,
  ),
  Mastercourselist(
    title: "Non Traditional Manufacturing Processes",
    id: "MF F318",
    credits: 3,
  ),
  Mastercourselist(title: "Supply Chain Management", id: "MF F319", credits: 3),
  Mastercourselist(
    title: "Engineering Optimization",
    id: "MF F320",
    credits: 3,
  ),
  Mastercourselist(title: "Procurement Management", id: "MF F321", credits: 3),
  Mastercourselist(title: "Design of Machine Tools", id: "MF F341", credits: 3),
  Mastercourselist(title: "Computer Aided Design", id: "MF F342", credits: 4),
  Mastercourselist(title: "Casting and Welding", id: "MF F343", credits: 4),
  Mastercourselist(
    title: "Engineering Optimization",
    id: "MF F344",
    credits: 2,
  ),
  Mastercourselist(title: "Lab Project", id: "MF F366", credits: 3),
  Mastercourselist(title: "Lab Project", id: "MF F367", credits: 3),
  Mastercourselist(title: "Design Project", id: "MF F376", credits: 3),
  Mastercourselist(title: "Design Project", id: "MF F377", credits: 3),
  Mastercourselist(title: "Fluid Power Systems", id: "MF F411", credits: 4),
  Mastercourselist(title: "Automotive Systems", id: "MF F412", credits: 3),
  Mastercourselist(
    title: "Mechanical Vibrations and Acoustics",
    id: "MF F413",
    credits: 3,
  ),
  Mastercourselist(
    title: "Manufacturing Excellence",
    id: "MF F414",
    credits: 3,
  ),
  Mastercourselist(title: "Noise Engineering", id: "MF F415", credits: 3),
  Mastercourselist(title: "Work System Design", id: "MF F416", credits: 3),
  Mastercourselist(title: "Lean Manufacturing", id: "MF F418", credits: 3),
  Mastercourselist(title: "Supply Chain Management", id: "MF F421", credits: 4),
  Mastercourselist(
    title: "Supply Chain Modelling and Empirical Analysis",
    id: "MF F422",
    credits: 4,
  ),
  Mastercourselist(
    title: "Advances in Materials Science",
    id: "MF F442",
    credits: 3,
  ),
  Mastercourselist(title: "Industrial Relations", id: "MF F453", credits: 3),
  Mastercourselist(title: "Maintenance and Safety", id: "MF F463", credits: 3),
  Mastercourselist(
    title: "Instrumentation and Control",
    id: "MF F471",
    credits: 3,
  ),
  Mastercourselist(title: "Precision Engineering", id: "MF F472", credits: 3),
  Mastercourselist(
    title: "Product Design and Development",
    id: "MF F473",
    credits: 3,
  ),
  Mastercourselist(
    title: "Product Design and Development Projects",
    id: "MF F474",
    credits: 3,
  ),
  Mastercourselist(
    title: "Sustainable Manufacturing",
    id: "MF F485",
    credits: 3,
  ),
  Mastercourselist(title: "Special Projects", id: "MF F491", credits: 3),

  //abcdef
  Mastercourselist(
    title: "Principles of Management",
    id: "MGTS F211",
    credits: 3,
  ),
  Mastercourselist(title: "Marketing", id: "MGTS F311", credits: 3),
  Mastercourselist(
    title: "Product and Brand Management",
    id: "MGTS F313",
    credits: 3,
  ),
  Mastercourselist(
    title: "Managerial and Leadership Skills",
    id: "MGTS F315",
    credits: 3,
  ),
  Mastercourselist(
    title: "Organisational Behaviour",
    id: "MGTS F351",
    credits: 3,
  ),
  Mastercourselist(
    title: "Advertising and Sales Promotion",
    id: "MGTS F433",
    credits: 3,
  ),

  //abcdef
  Mastercourselist(
    title: "Materials Characterisation",
    id: "MST F331",
    credits: 4,
  ),

  Mastercourselist(title: "Materials Processing", id: "MST F332", credits: 3),

  Mastercourselist(
    title: "Introduction to Biomaterials",
    id: "MST F333",
    credits: 3,
  ),

  Mastercourselist(
    title: "Materials for Catalytic Applications",
    id: "MST F334",
    credits: 3,
  ),

  Mastercourselist(
    title: "Coating and Thin Film Technology",
    id: "MST F335",
    credits: 3,
  ),

  Mastercourselist(title: "Glass Technology", id: "MST F336", credits: 3),

  Mastercourselist(
    title: "Materials for Energy Applications",
    id: "MST F337",
    credits: 3,
  ),

  Mastercourselist(title: "Metals and Alloys", id: "MST F338", credits: 3),

  Mastercourselist(title: "Polymer Materials", id: "MST F339", credits: 3),

  Mastercourselist(
    title: "Material Characterization Techniques",
    id: "MST G521",
    credits: 5,
  ),
  Mastercourselist(title: "Advanced Composites", id: "MST G522", credits: 5),

  //abcdef
  Mastercourselist(title: "Mechantronics", id: "MSE G511", credits: 5),

  //abcdef
  Mastercourselist(
    title: "Material Characterization Techniques",
    id: "MST G521",
    credits: 5,
  ),
  Mastercourselist(title: "Advanced Composites", id: "MST G522", credits: 5),

  //abcdef
  Mastercourselist(
    title: "Pharmaceutical Analysis",
    id: "PHA F211",
    credits: 3,
  ),

  Mastercourselist(title: "Dispensing Pharmacy", id: "PHA F212", credits: 3),

  Mastercourselist(title: "MicroBiology", id: "PHA F213", credits: 3),

  Mastercourselist(
    title: "Anatomy, Physiology & Hygiene",
    id: "PHA F214",
    credits: 3,
  ),

  Mastercourselist(
    title: "Introduction to Molecular Biology and Immunology",
    id: "PHA F215",
    credits: 3,
  ),

  Mastercourselist(
    title: "Pharmaceutical Formulations I",
    id: "PHA F216",
    credits: 3,
  ),
  Mastercourselist(
    title: "Pharmaceutical Microbiology",
    id: "PHA F217",
    credits: 3,
  ),
  Mastercourselist(
    title: "Pharmaceutical Chemistry",
    id: "PHA F241",
    credits: 3,
  ),
  Mastercourselist(title: "Biological Chemistry", id: "PHA F242", credits: 3),
  Mastercourselist(title: "Industrial Pharmacy", id: "PHA F243", credits: 3),
  Mastercourselist(title: "Physical Pharmacy", id: "PHA F244", credits: 3),
  Mastercourselist(title: "Study Project", id: "PHA F266", credits: 3),

  Mastercourselist(title: "Pharmacology I", id: "PHA F311", credits: 3),
  Mastercourselist(title: "Medicinal Chemistry I", id: "PHA F312", credits: 3),
  Mastercourselist(
    title: "Instrumental Methods of Analysis",
    id: "PHA F313",
    credits: 4,
  ),
  Mastercourselist(
    title: "Pharmaceutical Formulations and Biopharmaceutics",
    id: "PHA F314",
    credits: 3,
  ),

  Mastercourselist(
    title: "Pharmaceutical Formulations II",
    id: "PHA F315",
    credits: 3,
  ),
  Mastercourselist(title: "Pharmacology II", id: "PHA F341", credits: 3),
  Mastercourselist(title: "Medicinal Chemistry II", id: "PHA F342", credits: 3),
  Mastercourselist(title: "Forensic Pharmacy", id: "PHA F343", credits: 2),
  Mastercourselist(title: "Natural Drugs", id: "PHA F344", credits: 3),
  Mastercourselist(
    title: "Pharmaceutical Regulatory Science",
    id: "PHA F316",
    credits: 3,
  ),
  Mastercourselist(
    title: "Safety Pharmacology and Toxicology",
    id: "PHA F317",
    credits: 3,
  ),
  Mastercourselist(
    title: "Pharmaceutical Management and Quality Control",
    id: "PHA F413",
    credits: 3,
  ),
  Mastercourselist(title: "Biopharmaceutics", id: "PHA F414", credits: 3),
  Mastercourselist(title: "Pathophysiology", id: "PHA F415", credits: 3),
  Mastercourselist(
    title: "Chemistry of Synthetic Drugs",
    id: "PHA F416",
    credits: 3,
  ),
  Mastercourselist(title: "Pharmacoeconomics", id: "PHA F417", credits: 3),
  Mastercourselist(
    title: "Biopharmaceutics and Pharmacokinetics",
    id: "PHA F418",
    credits: 3,
  ),
  Mastercourselist(title: "Herbal Drug Technology", id: "PHA F419", credits: 3),
  Mastercourselist(title: "Cosmetic Science", id: "PHA F422", credits: 3),
  Mastercourselist(title: "Hospital Pharmacy", id: "PHA F432", credits: 3),
  Mastercourselist(
    title: "Biochemical Engineering",
    id: "PHA F441",
    credits: 3,
  ),
  Mastercourselist(
    title: "Applied Pharmaceutical Chemistry",
    id: "PHA F442",
    credits: 3,
  ),
  Mastercourselist(title: "Phytochemistry", id: "PHA F461", credits: 3),
  Mastercourselist(
    title: "Pharmaceutical Biostatistics",
    id: "PHA G546",
    credits: 3,
  ),

  Mastercourselist(title: "Lab Project", id: "PHA F366", credits: 3),
  Mastercourselist(title: "Lab Project", id: "PHA F367", credits: 3),
  Mastercourselist(title: "Design Project", id: "PHA F376", credits: 3),
  Mastercourselist(title: "Design Project", id: "PHA F377", credits: 3),

  Mastercourselist(title: "Special Projects", id: "PHA F491", credits: 3),

  //abcdef
  Mastercourselist(title: "General Physics", id: "PHY F112", credits: 3),
  Mastercourselist(title: "Classical Mechanics", id: "PHY F211", credits: 4),
  Mastercourselist(
    title: "Electromagnetic Theory I",
    id: "PHY F212",
    credits: 3,
  ),
  Mastercourselist(title: "Optics", id: "PHY F213", credits: 3),
  Mastercourselist(
    title: "Electricity, Magnetism & Optics Laboratory",
    id: "PHY F214",
    credits: 2,
  ),
  Mastercourselist(
    title: "Introduction to Astronomy and Astrophysics",
    id: "PHY F215",
    credits: 3,
  ),
  Mastercourselist(
    title: "Electromagnetic Theory II",
    id: "PHY F241",
    credits: 4,
  ),
  Mastercourselist(title: "Quantum Mechanics I", id: "PHY F242", credits: 3),
  Mastercourselist(
    title: "Mathematical Methods of Physics",
    id: "PHY F243",
    credits: 3,
  ),
  Mastercourselist(
    title: "Modern Physics Laboratory",
    id: "PHY F244",
    credits: 2,
  ),
  Mastercourselist(title: "Study Project", id: "PHY F266", credits: 3),
  Mastercourselist(title: "Quantum Mechanics II", id: "PHY F311", credits: 3),
  Mastercourselist(title: "Statistical Mechanics", id: "PHY F312", credits: 3),
  Mastercourselist(title: "Computational Physics", id: "PHY F313", credits: 3),
  Mastercourselist(title: "Theory of Relativity", id: "PHY F315", credits: 3),
  Mastercourselist(title: "Solid State Physics", id: "PHY F341", credits: 3),
  Mastercourselist(
    title: "Atomic & Molecular Physics",
    id: "PHY F342",
    credits: 3,
  ),
  Mastercourselist(
    title: "Nuclear & Particle Physics",
    id: "PHY F343",
    credits: 3,
  ),
  Mastercourselist(
    title: "Advanced Physics Laboratory",
    id: "PHY F344",
    credits: 3,
  ),
  Mastercourselist(
    title: "Quantum Mechanics for Engineers",
    id: "PHY F345",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction to Astronomy & Astrophysics",
    id: "PHY F215",
    credits: 3,
  ),
  Mastercourselist(title: "Musical Acoustics", id: "PHY F316", credits: 3),
  Mastercourselist(
    title: "Introduction to Radio Astronomy",
    id: "PHY F317",
    credits: 3,
  ),
  Mastercourselist(title: "Lab Project", id: "PHY F366", credits: 3),
  Mastercourselist(title: "Lab Project", id: "PHY F367", credits: 3),
  Mastercourselist(title: "Design Project", id: "PHY F376", credits: 3),
  Mastercourselist(title: "Design Project", id: "PHY F377", credits: 3),
  Mastercourselist(
    title: "Plasma Physics and its Applications",
    id: "PHY F378",
    credits: 3,
  ),
  Mastercourselist(title: "Thin Film Technology", id: "PHY F379", credits: 3),
  Mastercourselist(
    title: "Laser Science and Technology",
    id: "PHY F346",
    credits: 3,
  ),
  Mastercourselist(
    title: "Introduction To Quantum Field Theory",
    id: "PHY F412",
    credits: 4,
  ),
  Mastercourselist(title: "Particle Physics", id: "PHY F413", credits: 4),
  Mastercourselist(
    title: "Physics of Advanced Materials",
    id: "PHY F414",
    credits: 4,
  ),
  Mastercourselist(
    title: "General Theory of Relativity and Cosmology",
    id: "PHY F415",
    credits: 4,
  ),
  Mastercourselist(
    title: "Soft Condensed Matter Physics",
    id: "PHY F416",
    credits: 4,
  ),
  Mastercourselist(
    title: "Experimental Methods of Physics",
    id: "PHY F417",
    credits: 4,
  ),
  Mastercourselist(
    title: "Lasers and Applications",
    id: "PHY F418",
    credits: 4,
  ),
  Mastercourselist(
    title: "Advanced Solid State Physics",
    id: "PHY F419",
    credits: 4,
  ),
  Mastercourselist(title: "Quantum Optics", id: "PHY F420", credits: 4),
  Mastercourselist(
    title: "Advanced Quantum Mechanics",
    id: "PHY F421",
    credits: 4,
  ),
  Mastercourselist(
    title: "Group Theory and Applications",
    id: "PHY F422",
    credits: 4,
  ),
  Mastercourselist(
    title: "Special Topics in Statistical Mechanics",
    id: "PHY F423",
    credits: 4,
  ),
  Mastercourselist(
    title: "Advanced Electrodynamics",
    id: "PHY F424",
    credits: 4,
  ),
  Mastercourselist(
    title: "Advanced Mathematical Methods of Physics",
    id: "PHY F425",
    credits: 4,
  ),
  Mastercourselist(
    title: "Physics of Semiconductor Devices",
    id: "PHY F426",
    credits: 4,
  ),
  Mastercourselist(title: "Atmospheric Physics", id: "PHY F427", credits: 3),
  Mastercourselist(
    title: "Quantum Information Theory",
    id: "PHY F428",
    credits: 3,
  ),
  Mastercourselist(
    title: "Geometrical Methods in Physics",
    id: "PHY F431",
    credits: 3,
  ),
  Mastercourselist(
    title: "Classical Theory of Fields: A Symmetry Perspective",
    id: "PHY F432",
    credits: 4,
  ),
  Mastercourselist(
    title: "Topics in Nonlinear Optics",
    id: "PHY F433",
    credits: 3,
  ),
  Mastercourselist(
    title: "Foundations of Quantum Mechanics",
    id: "PHY F434",
    credits: 3,
  ),
  Mastercourselist(
    title: "Advanced Quantum Field Theory",
    id: "PHY G512",
    credits: 3,
  ),

  Mastercourselist(title: "Special Projects", id: "PHY F491", credits: 3),

  //abcdef
  Mastercourselist(title: "Electrical Sciences", id: "EEE F111", credits: 3),
  Mastercourselist(title: "Electrical Machines", id: "EEE F211", credits: 3),
  Mastercourselist(title: "Electromagnetic Theory", id: "EEE F212", credits: 3),
  Mastercourselist(title: "Electronic Devices", id: "EEE F214", credits: 3),
  Mastercourselist(title: "Digital Design", id: "EEE F215", credits: 3),
  Mastercourselist(
    title: "Microprocessors and Interfacing",
    id: "EEE F241",
    credits: 3,
  ),
  Mastercourselist(title: "Control Systems", id: "EEE F242", credits: 3),
  Mastercourselist(title: "Signals & Systems", id: "EEE F243", credits: 3),
  Mastercourselist(
    title: "Microelectronic Circuits",
    id: "EEE F244",
    credits: 3,
  ),
  Mastercourselist(
    title: "Control System Laboratory",
    id: "EEE F245",
    credits: 1,
  ),
  Mastercourselist(
    title: "Electrical and Electronic Circuits Laboratory",
    id: "EEE F246",
    credits: 2,
  ),
  Mastercourselist(title: "Study Project", id: "EEE F266", credits: 3),
  Mastercourselist(title: "Communication Systems", id: "EEE F311", credits: 3),
  Mastercourselist(title: "Power Systems", id: "EEE F312", credits: 3),
  Mastercourselist(
    title: "Analog & Digital VLSI Design",
    id: "EEE F313",
    credits: 3,
  ),
  Mastercourselist(title: "Analog Electronics", id: "EEE F341", credits: 3),
  Mastercourselist(title: "Power Electronics", id: "EEE F342", credits: 3),
  Mastercourselist(
    title: "Power Apparatus and Networks",
    id: "EEE F345",
    credits: 3,
  ),
  Mastercourselist(
    title: "Data Communication Networks",
    id: "EEE F346",
    credits: 2,
  ),
  Mastercourselist(
    title: "Communication Networks Laboratory",
    id: "EEE F347",
    credits: 2,
  ),
  Mastercourselist(
    title: "FPGA Based System Design Laboratory",
    id: "EEE F348",
    credits: 2,
  ),
  Mastercourselist(title: "Lab Project", id: "EEE F366", credits: 3),
  Mastercourselist(title: "Lab Project", id: "EEE F367", credits: 3),
  Mastercourselist(title: "Design Project", id: "EEE F376", credits: 3),
  Mastercourselist(title: "Design Project", id: "EEE F377", credits: 3),
  Mastercourselist(
    title: "Electrical Sciences Laboratory",
    id: "EEE F112",
    credits: 1,
  ),

  Mastercourselist(
    title: "Electrical Machines Laboratory",
    id: "EEE F213",
    credits: 2,
  ),

  Mastercourselist(
    title: "Electronic Devices Laboratory",
    id: "EEE F216",
    credits: 2,
  ),

  Mastercourselist(
    title: "Digital Design Laboratory",
    id: "EEE F217",
    credits: 2,
  ),

  Mastercourselist(
    title: "Power Systems Laboratory",
    id: "EEE F316",
    credits: 2,
  ),

  Mastercourselist(
    title: "Analog & Digital VLSI Design Laboratory",
    id: "EEE F317",
    credits: 2,
  ),

  Mastercourselist(
    title: "Analog Electronics Laboratory",
    id: "EEE F343",
    credits: 2,
  ),

  Mastercourselist(
    title: "Power Electronics Laboratory",
    id: "EEE F344",
    credits: 2,
  ),
  Mastercourselist(title: "Advanced Power Systems", id: "EEE 462", credits: 3),

  Mastercourselist(title: "Satellite Communication", id: "EEE 472", credits: 3),

  Mastercourselist(title: "Wind Electrical Systems", id: "EEE 473", credits: 3),

  Mastercourselist(
    title: "Antenna Theory and Design",
    id: "EEE 474",
    credits: 4,
  ),

  Mastercourselist(
    title: "Special Electrical Machines",
    id: "EEE 475",
    credits: 4,
  ),

  Mastercourselist(
    title: "Switch Gear and Protection",
    id: "EEE 476",
    credits: 4,
  ),

  Mastercourselist(
    title: "Modelling of Field Effect Nanodevices",
    id: "EEE 477",
    credits: 3,
  ),

  Mastercourselist(
    title: "Power Systems Laboratory",
    id: "EEE 478",
    credits: 3,
  ),

  Mastercourselist(title: "Special Projects", id: "EEE F491", credits: 3),

  Mastercourselist(title: "Study Project", id: "EEE F266", credits: 3),
  Mastercourselist(title: "Embedded System Design", id: "EEE G512", credits: 4),
  Mastercourselist(
    title: "Hardware Software COde Design",
    id: "EEE G626",
    credits: 4,
  ),

  Mastercourselist(title: "Data Structures & Algorithms", id: "ECOM F211", credits: 4),
  Mastercourselist(title: "Electronic Devices", id: "ECOM F214", credits: 3),
  Mastercourselist(title: "Object Oriented Programming", id: "ECOM F213", credits: 4),
  Mastercourselist(title: "Digital Design", id: "ECOM F215", credits: 4),
  Mastercourselist(title: "Discrete Structures for CS", id: "ECOM F222", credits: 3),
  Mastercourselist(title: "Microprocessors and Interfacing", id: "ECOM F241", credits: 4),
  Mastercourselist(title: "Control Systems", id: "ECOM F242", credits: 3),
  Mastercourselist(title: "Signals & Systems", id: "ECOM F243", credits: 3),
  Mastercourselist(title: "Microelectronic Circuits", id: "ECOM F244", credits: 3),
  Mastercourselist(title: "Analog & Digital VLSI Design", id: "ECOM F313", credits: 3),
  Mastercourselist(title: "Real Time Operating Systems", id: "ECOM F321", credits: 4),
  Mastercourselist(title: "Computer Architecture", id: "ECOM F342", credits: 4),
  Mastercourselist(title: "Communication Networks", id: "ECOM F343", credits: 3),
  Mastercourselist(title: "Network Programming", id: "ECOM F462", credits: 3),
];