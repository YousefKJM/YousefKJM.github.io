// 2024 CISSP outline coverage: study notes and glossary terms for outline subtopics
// not covered elsewhere (checked against the ISC2 outline effective April 15, 2024).
(() => {
const S = window.STUDY, G = window.GLOSSARY;
const add = (d, notes) => S[d].push(...notes);

add(1, [
  'Frameworks named in the outline: ISO 27001/27002, NIST CSF and SP 800-53, COBIT (IT governance), SABSA (business-driven security architecture), PCI DSS (card data) and FedRAMP (US government cloud authorization).',
  'Privacy laws beyond GDPR and CCPA: China\'s PIPL (strict cross-border transfer rules) and South Africa\'s POPIA. Expect questions on extraterritorial reach and transfer mechanisms, not article numbers.',
  'BC planning must cover external dependencies (cloud providers, ISPs, utilities, key suppliers). Your RTO is only as good as theirs, so check their SLAs and continuity plans.',
  'Supply chain mitigations in the outline: third-party assessment and monitoring, minimum security requirements, SLRs, silicon root of trust, physically unclonable functions (PUF) and SBOMs.',
  'Awareness programs: phishing simulations, security champions embedded in teams, gamification, and periodic content updates for emerging technology and threats (AI deepfakes, cryptocurrency and blockchain scams). Measure effectiveness, not attendance.',
]);
add(2, [
  'End of life (EOL) and end of support (EOS): no more patches means rising risk. Plan replacement before EOS. If you can\'t replace it, isolate the asset and add compensating controls, and record the risk acceptance.',
]);
add(3, [
  'SASE (secure access service edge) delivers networking (SD-WAN) and security (SWG, CASB, ZTNA, FWaaS) together from the cloud, close to users.',
  'Cryptanalytic attacks in the outline also include frequency analysis, fault injection (glitching a device to leak keys), and attacks on the surrounding implementation: pass-the-hash, Kerberos exploitation and ransomware.',
  'Other architectures to secure: HPC clusters (shared nodes, valuable research data), edge computing (physically exposed, hard to patch), microservices (API gateway, mTLS, service mesh) and distributed systems (trust and consistency between nodes).',
  'Systems lifecycle (3.10): stakeholder needs, requirements analysis, architecture, development, integration, verification and validation, deployment, operations and maintenance, retirement. Verification asks "built right?" and validation asks "built the right thing?"',
  'Facility design also covers wiring closets/IDFs (locked, monitored, never shared with janitorial storage), media storage and evidence storage (restricted access, logging, environmental controls, chain of custody).',
]);
add(4, [
  'IP delivery types: unicast (one to one), broadcast (all on the segment), multicast (one to subscribed group), anycast (one address announced from many sites; traffic reaches the nearest, which helps absorb DDoS).',
  'Traffic flows: north-south crosses the perimeter, east-west moves between internal workloads. Most lateral movement is east-west, so microsegmentation matters.',
  'Segmentation options: physical (air gap, out-of-band management network) and logical (VLANs, VPNs, VRF routing tables, virtual domains). In the cloud, a VPC is your isolated virtual network.',
  'Converged and modern transport: iSCSI, VoIP, InfiniBand over Ethernet (RoCE) and Compute Express Link (CXL) for memory sharing. Switches forward cut-through (fast, may pass bad frames) or store-and-forward (checks the frame first).',
  'Performance metrics: bandwidth, latency, jitter (variation in delay; it hurts voice and video), throughput and signal-to-noise ratio. QoS prioritizes sensitive traffic.',
  'Wireless and remote channels: Zigbee (low-power IoT mesh), satellite (high latency, jamming and interception risk), cellular 4G/5G, and backhaul links from edge sites to the core. Contract and monitor third-party connectivity such as telecom and vendor support links.',
  'SDN extends to SD-WAN and NFV (network functions such as firewalls running as software). Network observability combines logs, metrics and traces for capacity and fault management.',
]);
add(6, [
  'Report findings with remediation, exception handling (documented, owned, time-bound) and ethical disclosure: coordinate with the vendor and give them time to fix before going public.',
  'Compliance checks automatically compare configurations against approved baselines and policies (e.g., SCAP, CIS benchmarks), producing continuous evidence.',
]);
add(7, [
  'Mobile artifacts: isolate seized phones from networks (Faraday bag) to stop remote wipe, and record the device state. Collection often needs specialized tools.',
  'Detection tools now include AI and machine learning (ML) based analytics. They find anomalies at scale but bring false positives, model drift and poisoning risks, so keep humans in the loop.',
  'Third-party security services (MSSP, MDR) can run monitoring, but accountability stays with you. Define SLAs, escalation and log ownership in the contract.',
]);
add(8, [
  'Methodologies in the outline include the Scaled Agile Framework (SAFe) for many coordinated agile teams, and Integrated Product Teams (IPT) that bring development, security, operations and business stakeholders together for a product\'s whole lifecycle.',
  'Acquired software: COTS (no source code, so rely on vendor assurance and hardening), open source (SCA, community health), third-party and managed services, and cloud (shared responsibility, contract terms).',
  'Software-defined security means controls defined as code and policies, enforced through APIs and automation rather than tied to hardware.',
]);

G.push(
  {d:1,t:"SABSA",x:"Sherwood Applied Business Security Architecture. Business-driven, risk-based framework for enterprise security architecture built on a layered matrix of what/why/how/who/where/when."},
  {d:1,t:"FedRAMP",x:"US government program that standardizes security assessment, authorization and continuous monitoring of cloud services used by federal agencies. Based on NIST SP 800-53."},
  {d:1,t:"PIPL",x:"China's Personal Information Protection Law (2021). Extraterritorial reach and strict cross-border transfer rules (security assessment, standard contract or certification)."},
  {d:1,t:"POPIA",x:"South Africa's Protection of Personal Information Act. Lawful processing conditions, enforced by the Information Regulator."},
  {d:1,t:"External dependencies",x:"Suppliers, utilities, ISPs and cloud providers your critical processes rely on. Include them in the BIA and BC plans, and check their SLAs and resilience."},
  {d:1,t:"Control assessment",x:"Testing whether security and privacy controls are implemented correctly, operating as intended and producing the desired outcome (e.g., NIST SP 800-53A)."},
  {d:1,t:"Risk maturity model",x:"Scale for rating how mature the risk management program is (ad hoc to optimized). Used to drive continuous improvement."},
  {d:1,t:"Silicon root of trust",x:"Immutable trust anchor built into a chip that verifies firmware and boot code before it runs, guarding against tampered or implanted components."},
  {d:1,t:"Physically unclonable function (PUF)",x:"Uses tiny manufacturing variations in silicon to produce a unique device fingerprint or key that can't be cloned. Counters counterfeit hardware."},
  {d:1,t:"Security champions",x:"Staff embedded in business or development teams who promote secure practices and act as a link to the security team."},
  {d:1,t:"Gamification",x:"Using game elements (points, leaderboards, challenges) in awareness training to raise engagement and retention."},
  {d:2,t:"End of life / end of support",x:"EOL: vendor stops selling. EOS: vendor stops patches and support. Plan replacement, or isolate the asset with compensating controls and documented risk acceptance."},
  {d:3,t:"SASE",x:"Secure Access Service Edge. Cloud-delivered convergence of SD-WAN with security services (SWG, CASB, ZTNA, FWaaS)."},
  {d:3,t:"Frequency analysis",x:"Breaking substitution ciphers by matching ciphertext symbol frequencies to known language letter frequencies."},
  {d:3,t:"Fault injection",x:"Deliberately inducing faults (voltage or clock glitching, lasers, EM pulses) so a device computes incorrectly and leaks keys or skips checks."},
  {d:3,t:"Edge computing",x:"Processing data near where it is generated. Physically exposed, widely distributed nodes are hard to patch and monitor."},
  {d:3,t:"High-performance computing (HPC)",x:"Clusters for heavy computation. Risks: shared nodes, high-value research data, and security traded off for performance."},
  {d:3,t:"Microservices",x:"Small, independently deployed services talking over APIs. Secure with an API gateway, mutual TLS, a service mesh and least-privilege service identities."},
  {d:3,t:"Verification vs validation",x:"Verification: did we build it right (meets specification)? Validation: did we build the right thing (meets stakeholder needs)?"},
  {d:3,t:"Evidence storage",x:"Secured, access-controlled and logged storage with environmental protection that preserves chain of custody."},
  {d:4,t:"Anycast",x:"One IP address announced from many locations; routing delivers to the nearest. Used by DNS and CDNs, and it spreads DDoS load."},
  {d:4,t:"Multicast",x:"One-to-many delivery to hosts that join a group (IGMP). Efficient for streaming."},
  {d:4,t:"North-south vs east-west",x:"North-south: traffic entering or leaving the data center. East-west: traffic between internal workloads, where lateral movement happens."},
  {d:4,t:"Out-of-band management",x:"Separate, dedicated network for administering devices. Keeps admin access isolated and available during production outages."},
  {d:4,t:"VRF",x:"Virtual Routing and Forwarding. Multiple independent routing tables on one router for Layer 3 logical segmentation."},
  {d:4,t:"VPC",x:"Virtual Private Cloud. Logically isolated network inside a public cloud with its own subnets, routes and security groups."},
  {d:4,t:"Compute Express Link (CXL)",x:"High-speed, cache-coherent interconnect over PCIe for sharing memory between CPUs, accelerators and memory devices."},
  {d:4,t:"InfiniBand over Ethernet",x:"Running InfiniBand-style RDMA over Ethernet (RoCE). Low-latency converged protocol for HPC and storage."},
  {d:4,t:"Cut-through vs store-and-forward",x:"Cut-through forwards once the destination is read (fast, may pass corrupt frames). Store-and-forward checks the whole frame first."},
  {d:4,t:"Jitter",x:"Variation in packet delay. Degrades real-time voice and video. QoS and jitter buffers help."},
  {d:4,t:"QoS",x:"Quality of Service. Classifies and prioritizes traffic (e.g., voice) to guarantee bandwidth and latency."},
  {d:4,t:"Zigbee",x:"Low-power IEEE 802.15.4 mesh protocol for IoT. Uses AES-128, but weak key handling during pairing is a known risk."},
  {d:4,t:"NFV",x:"Network Functions Virtualization. Firewalls, routers and load balancers run as software on standard servers."},
  {d:4,t:"Backhaul",x:"Links carrying traffic from edge or access sites (e.g., cell towers, branches) to the core network."},
  {d:4,t:"Network observability",x:"Using logs, metrics, flows and traces to understand network behavior for capacity, fault and security management."},
  {d:6,t:"Ethical disclosure",x:"Reporting a vulnerability privately to the vendor and allowing reasonable time to fix before public release (coordinated disclosure)."},
  {d:6,t:"Compliance checks",x:"Automated comparison of system configurations against required baselines and policies, producing ongoing audit evidence."},
  {d:7,t:"Faraday bag",x:"Shielded bag that blocks radio signals so a seized mobile device can't be remotely wiped or altered."},
  {d:7,t:"MDR / MSSP",x:"Managed Detection and Response / Managed Security Service Provider. Outsourced monitoring and response; accountability stays with the customer."},
  {d:8,t:"SAFe",x:"Scaled Agile Framework. Coordinates many agile teams through agile release trains and program increments."},
  {d:8,t:"Integrated Product Team (IPT)",x:"Cross-functional team (development, security, operations, business) responsible for a product across its lifecycle."},
  {d:8,t:"COTS",x:"Commercial off-the-shelf software. No source code access, so rely on vendor assurance, testing and secure configuration."},
  {d:8,t:"Software-defined security",x:"Security controls expressed as code and policy and enforced through APIs and automation, independent of hardware."},
);

// ── AI and cloud (outline 1.12, 3.5, 7.7 and cloud items across domains) ──
add(1, [
  'AI governance: leadership owns AI risk (often through an AI governance committee). Start with an AI acceptable-use policy covering approved tools, which data classes may be entered, and human review. Then discover shadow AI and offer sanctioned alternatives.',
  'AI frameworks and law: NIST AI RMF (Govern, Map, Measure, Manage), ISO/IEC 42001 (certifiable AI management system), and the EU AI Act (risk tiers: prohibited, high-risk, limited, minimal). For vendors, check whether your data trains their models, plus retention, residency and subprocessors.',
  'Cloud assurance: you rarely audit a hyperscaler yourself, so rely on SOC 2 Type II, ISO 27001 and CSA STAR mapped to your requirements (CSA CCM and its CAIQ questionnaire). Data residency covers backups, logs and support access too. Plan an exit strategy (export formats, transition support, verified deletion).',
]);
add(3, [
  'Attacks on AI: data poisoning (corrupt training data), evasion (adversarial examples at inference), model inversion and membership inference (leak training data), model extraction (steal the model by querying it), and prompt injection. MITRE ATLAS catalogs these.',
  'Cloud architecture risks: misconfiguration is the top cause of breaches, so use CSPM for runtime drift and IaC scanning before deployment. Multi-tenancy brings isolation and side-channel risk; use dedicated hosts or confidential computing for the most sensitive workloads.',
]);
add(7, [
  "Cloud forensics: you can't seize the provider's hardware and instances are ephemeral. Plan ahead with central logging, retention, automated snapshots on alert, and contract terms for log access and provider support.",
]);
add(8, [
  'Building with LLMs (OWASP Top 10 for LLM Applications): treat model output as untrusted, enforce user permissions at retrieval (RAG), limit agent tools to avoid excessive agency, ground answers to reduce hallucinations, verify the provenance of downloaded models, and red team before launch.',
]);
G.push(
  {d:1,t:"NIST AI RMF",x:"NIST AI Risk Management Framework. Voluntary guidance with four functions: Govern, Map, Measure, Manage."},
  {d:1,t:"ISO/IEC 42001",x:"Certifiable standard for an AI management system (AIMS), the AI counterpart to ISO 27001."},
  {d:1,t:"EU AI Act",x:"EU regulation classifying AI by risk: unacceptable (prohibited), high-risk (strict obligations such as human oversight and data governance), limited (transparency) and minimal."},
  {d:1,t:"Shadow AI",x:"AI tools used without IT or security approval, which can move sensitive data outside organizational controls."},
  {d:1,t:"CSA CCM / CAIQ",x:"Cloud Security Alliance Cloud Controls Matrix (cloud control framework mapped to ISO and NIST) and the Consensus Assessments Initiative Questionnaire used to document providers' controls."},
  {d:3,t:"Data poisoning",x:"Corrupting training data so a model learns attacker-chosen behavior."},
  {d:3,t:"Model inversion",x:"Querying a model to reconstruct or infer sensitive training data. Related to membership inference."},
  {d:3,t:"Model extraction",x:"Recreating a proprietary model by systematically querying it. Counter with authentication, rate limiting and monitoring."},
  {d:3,t:"Adversarial example",x:"Input with subtle, crafted changes that cause a model to misclassify it (evasion attack)."},
  {d:3,t:"MITRE ATLAS",x:"Knowledge base of adversary tactics and techniques against AI/ML systems, modeled on ATT&CK."},
  {d:3,t:"CSPM",x:"Cloud Security Posture Management. Continuously detects cloud misconfigurations and compliance drift."},
  {d:8,t:"Excessive agency",x:"OWASP LLM risk: an AI agent given more tools or permissions than needed, so manipulation causes real damage. Counter with least privilege and human approval."},
  {d:8,t:"RAG",x:"Retrieval-augmented generation. The model answers using retrieved documents, so retrieval must enforce the user's permissions."},
);
})();
