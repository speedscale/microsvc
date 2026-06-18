const LOCALE_CYCLE = [
  'en-US', 'en-US', 'en-US', 'en-US', 'en-US',
  'en-GB', 'en-CA', 'en-AU',
  'es-MX', 'es-ES', 'fr-FR', 'de-DE', 'it-IT',
  'nl-NL', 'sv-SE', 'pl-PL', 'pt-BR',
  'ja-JP', 'ko-KR', 'zh-CN',
];

const PROFILE_BY_LOCALE = {
  'en-US': {
    language: 'English',
    firstNames: ['Olivia', 'Emma', 'Ava', 'Sophia', 'Mia', 'Charlotte', 'Amelia', 'Harper', 'Liam', 'Noah', 'Ethan', 'Lucas'],
    lastNames: ['Smith', 'Johnson', 'Williams', 'Brown', 'Miller', 'Davis', 'Wilson', 'Anderson', 'Taylor', 'Martin', 'Thompson', 'Clark'],
    questions: [
      "What's my account balance?",
      'Show me my recent transactions.',
      'Am I spending too much this month?',
      'What are my biggest expenses?',
    ],
  },
  'en-GB': {
    language: 'English',
    firstNames: ['Oliver', 'George', 'Harry', 'Jack', 'Arthur', 'Isla', 'Freya', 'Grace', 'Amelia', 'Florence'],
    lastNames: ['Smith', 'Jones', 'Taylor', 'Brown', 'Williams', 'Wilson', 'Evans', 'Thomas', 'Roberts', 'Walker'],
    questions: [
      "What's my current account balance?",
      'Can you show my latest transactions?',
      'Am I overspending this month?',
      'Which expenses are highest?',
    ],
  },
  'en-CA': {
    language: 'English',
    firstNames: ['Liam', 'Noah', 'William', 'Lucas', 'Benjamin', 'Emma', 'Olivia', 'Charlotte', 'Sophia', 'Ava'],
    lastNames: ['Smith', 'Brown', 'Tremblay', 'Martin', 'Roy', 'Wilson', 'Taylor', 'Campbell', 'Anderson', 'Lee'],
    questions: [
      "What's my account balance?",
      'Show me my recent transactions.',
      'Am I spending too much this month?',
      'What are my biggest expenses?',
    ],
  },
  'en-AU': {
    language: 'English',
    firstNames: ['Oliver', 'Noah', 'Jack', 'Henry', 'Leo', 'Charlotte', 'Olivia', 'Amelia', 'Isla', 'Mia'],
    lastNames: ['Smith', 'Jones', 'Williams', 'Brown', 'Wilson', 'Taylor', 'Martin', 'Anderson', 'Thompson', 'White'],
    questions: [
      "What's my account balance?",
      'Show my recent transactions.',
      'Am I spending too much lately?',
      'What are my largest expenses?',
    ],
  },
  'es-MX': {
    language: 'Spanish',
    firstNames: ['Sofia', 'Valentina', 'Camila', 'Regina', 'Mateo', 'Santiago', 'Diego', 'Emiliano', 'Lucia', 'Daniel'],
    lastNames: ['Garcia', 'Hernandez', 'Lopez', 'Martinez', 'Gonzalez', 'Perez', 'Rodriguez', 'Sanchez', 'Ramirez', 'Torres'],
    questions: [
      'Cual es el saldo de mi cuenta?',
      'Muestrame mis transacciones recientes.',
      'Estoy gastando demasiado este mes?',
      'Cuales son mis gastos mas grandes?',
    ],
  },
  'es-ES': {
    language: 'Spanish',
    firstNames: ['Lucia', 'Sofia', 'Martina', 'Maria', 'Julia', 'Hugo', 'Martin', 'Lucas', 'Leo', 'Daniel'],
    lastNames: ['Garcia', 'Rodriguez', 'Gonzalez', 'Fernandez', 'Lopez', 'Martinez', 'Sanchez', 'Perez', 'Gomez', 'Martin'],
    questions: [
      'Cual es el saldo de mi cuenta?',
      'Enseneme mis transacciones recientes.',
      'Estoy gastando demasiado este mes?',
      'Cuales son mis mayores gastos?',
    ],
  },
  'fr-FR': {
    language: 'French',
    firstNames: ['Camille', 'Lea', 'Chloe', 'Manon', 'Emma', 'Hugo', 'Louis', 'Gabriel', 'Arthur', 'Jules'],
    lastNames: ['Martin', 'Bernard', 'Dubois', 'Thomas', 'Robert', 'Richard', 'Petit', 'Durand', 'Leroy', 'Moreau'],
    questions: [
      'Quel est le solde de mon compte ?',
      'Montrez-moi mes transactions recentes.',
      'Est-ce que je depense trop ce mois-ci ?',
      'Quelles sont mes plus grosses depenses ?',
    ],
  },
  'de-DE': {
    language: 'German',
    firstNames: ['Emma', 'Mia', 'Hannah', 'Sofia', 'Lina', 'Ben', 'Paul', 'Leon', 'Finn', 'Felix'],
    lastNames: ['Muller', 'Schmidt', 'Schneider', 'Fischer', 'Weber', 'Meyer', 'Wagner', 'Becker', 'Hoffmann', 'Schulz'],
    questions: [
      'Wie hoch ist mein Kontostand?',
      'Zeigen Sie mir meine letzten Transaktionen.',
      'Gebe ich diesen Monat zu viel aus?',
      'Was sind meine groessten Ausgaben?',
    ],
  },
  'it-IT': {
    language: 'Italian',
    firstNames: ['Giulia', 'Sofia', 'Aurora', 'Alice', 'Ginevra', 'Leonardo', 'Francesco', 'Lorenzo', 'Alessandro', 'Mattia'],
    lastNames: ['Rossi', 'Russo', 'Ferrari', 'Esposito', 'Bianchi', 'Romano', 'Colombo', 'Ricci', 'Marino', 'Greco'],
    questions: [
      'Qual e il saldo del mio conto?',
      'Mostrami le mie transazioni recenti.',
      'Sto spendendo troppo questo mese?',
      'Quali sono le mie spese piu grandi?',
    ],
  },
  'nl-NL': {
    language: 'Dutch',
    firstNames: ['Emma', 'Tess', 'Sophie', 'Julia', 'Mila', 'Daan', 'Sem', 'Lucas', 'Finn', 'Levi'],
    lastNames: ['DeVries', 'Jansen', 'Bakker', 'Visser', 'Smit', 'Meijer', 'DeBoer', 'Mulder', 'Bos', 'Vos'],
    questions: [
      'Wat is mijn rekeningsaldo?',
      'Laat mijn recente transacties zien.',
      'Geef ik deze maand te veel uit?',
      'Wat zijn mijn grootste uitgaven?',
    ],
  },
  'sv-SE': {
    language: 'Swedish',
    firstNames: ['Alice', 'Elsa', 'Maja', 'Lilly', 'Ella', 'Oscar', 'Lucas', 'William', 'Liam', 'Noah'],
    lastNames: ['Andersson', 'Johansson', 'Karlsson', 'Nilsson', 'Eriksson', 'Larsson', 'Olsson', 'Persson', 'Svensson', 'Gustafsson'],
    questions: [
      'Vad ar saldot pa mitt konto?',
      'Visa mina senaste transaktioner.',
      'Spenderar jag for mycket den har manaden?',
      'Vilka ar mina storsta utgifter?',
    ],
  },
  'pl-PL': {
    language: 'Polish',
    firstNames: ['Zofia', 'Hanna', 'Julia', 'Maja', 'Laura', 'Jan', 'Antoni', 'Jakub', 'Aleksander', 'Szymon'],
    lastNames: ['Nowak', 'Kowalski', 'Wisniewski', 'Wojcik', 'Kowalczyk', 'Kaminski', 'Lewandowski', 'Zielinski', 'Szymanski', 'Dabrowski'],
    questions: [
      'Jakie jest saldo mojego konta?',
      'Pokaz moje ostatnie transakcje.',
      'Czy wydaje za duzo w tym miesiacu?',
      'Jakie sa moje najwieksze wydatki?',
    ],
  },
  'pt-BR': {
    language: 'Portuguese',
    firstNames: ['Ana', 'Beatriz', 'Mariana', 'Laura', 'Isabela', 'Joao', 'Pedro', 'Lucas', 'Miguel', 'Gabriel'],
    lastNames: ['Silva', 'Santos', 'Oliveira', 'Souza', 'Rodrigues', 'Ferreira', 'Alves', 'Pereira', 'Lima', 'Gomes'],
    questions: [
      'Qual e o saldo da minha conta?',
      'Mostre minhas transacoes recentes.',
      'Estou gastando demais este mes?',
      'Quais sao minhas maiores despesas?',
    ],
  },
  'ja-JP': {
    language: 'Japanese',
    firstNames: ['Yuki', 'Haruto', 'Sota', 'Yuto', 'Ren', 'Hina', 'Sakura', 'Aoi', 'Mei', 'Rin'],
    lastNames: ['Sato', 'Suzuki', 'Takahashi', 'Tanaka', 'Watanabe', 'Ito', 'Yamamoto', 'Nakamura', 'Kobayashi', 'Kato'],
    questions: [
      '口座残高を教えてください。',
      '最近の取引を見せてください。',
      '今月使いすぎていますか?',
      '一番大きな支出は何ですか?',
    ],
  },
  'ko-KR': {
    language: 'Korean',
    firstNames: ['SeoJun', 'DoYun', 'HaJun', 'JiHo', 'MinJun', 'SeoYeon', 'HaYoon', 'JiA', 'SeoAh', 'HaEun'],
    lastNames: ['Kim', 'Lee', 'Park', 'Choi', 'Jung', 'Kang', 'Cho', 'Yoon', 'Jang', 'Lim'],
    questions: [
      '내 계좌 잔액을 알려 주세요.',
      '최근 거래 내역을 보여 주세요.',
      '이번 달에 너무 많이 쓰고 있나요?',
      '가장 큰 지출은 무엇인가요?',
    ],
  },
  'zh-CN': {
    language: 'Chinese',
    firstNames: ['Wei', 'Fang', 'Jing', 'Lei', 'Ming', 'Hao', 'Chen', 'Liang', 'Mei', 'Yan'],
    lastNames: ['Wang', 'Li', 'Zhang', 'Liu', 'Chen', 'Yang', 'Huang', 'Zhao', 'Wu', 'Zhou'],
    questions: [
      '请告诉我账户余额。',
      '请显示我最近的交易。',
      '我这个月花得太多了吗?',
      '我最大的支出是什么?',
    ],
  },
};

function slug(value) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, '');
}

function getProfileForUserNumber(userNumber) {
  const index = Math.max(1, userNumber);
  const locale = LOCALE_CYCLE[(index - 1) % LOCALE_CYCLE.length];
  const profile = PROFILE_BY_LOCALE[locale];
  const firstName = profile.firstNames[(index * 7) % profile.firstNames.length];
  const lastName = profile.lastNames[(index * 11) % profile.lastNames.length];
  const padded = index.toString().padStart(3, '0');
  const username = `${slug(firstName)}.${slug(lastName)}.${padded}`;

  return {
    username,
    email: `${username}@northbridge.example`,
    firstName,
    lastName,
    displayName: `${firstName} ${lastName}`,
    locale,
    language: profile.language,
  };
}

function getRandomProfile() {
  const baseNumber = Math.floor(Math.random() * 1000) + 1;
  const profile = getProfileForUserNumber(baseNumber);
  const suffix = `${Date.now()}${Math.floor(Math.random() * 1000)}`;
  const username = `${profile.username}.${suffix}`;

  return {
    ...profile,
    username,
    email: `${username}@northbridge.example`,
  };
}

function getQuestionsForLocale(locale) {
  return (PROFILE_BY_LOCALE[locale] || PROFILE_BY_LOCALE['en-US']).questions;
}

module.exports = {
  LOCALE_CYCLE,
  PROFILE_BY_LOCALE,
  getProfileForUserNumber,
  getRandomProfile,
  getQuestionsForLocale,
};
