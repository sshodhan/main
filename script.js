const sparkleDisplay = document.getElementById('sparkleStars');
const sparkleContainer = document.getElementById('sparkleContainer');
const sparkleModeBtn = document.getElementById('sparkleMode');
const body = document.body;

const stars = {
  total: 0,
  add(count = 1) {
    this.total += count;
    sparkleDisplay.textContent = this.total;
    sparkleModeBtn.setAttribute('aria-label', `Sparkle boost. Stars earned: ${this.total}`);
    celebration.launch(count);
  },
};

const celebration = {
  launch(count = 6) {
    for (let i = 0; i < count; i += 1) {
      const sparkle = document.createElement('span');
      sparkle.className = 'sparkle';
      sparkle.style.left = `${Math.random() * 100}%`;
      sparkle.style.top = `${20 + Math.random() * 60}%`;
      sparkle.style.animationDelay = `${Math.random() * 0.4}s`;
      sparkleContainer.appendChild(sparkle);
      setTimeout(() => sparkle.remove(), 1600);
    }
  },
};

sparkleModeBtn.addEventListener('click', () => {
  body.classList.toggle('sparkle-mode');
  celebration.launch(12);
  sparkleModeBtn.textContent = body.classList.contains('sparkle-mode')
    ? 'Sparkle Boost On ✨'
    : 'Sparkle Boost ✨';
});

// Number Sense Meadow
const numberSense = (() => {
  const questionEl = document.getElementById('nsQuestion');
  const optionsEl = document.getElementById('nsOptions');
  const feedbackEl = document.getElementById('nsFeedback');
  const newBtn = document.getElementById('nsNew');

  const templates = [
    {
      prompt() {
        const tens = Math.floor(Math.random() * 8 + 2) * 10;
        const adjust = Math.floor(Math.random() * 18) - 9;
        const other = tens + adjust;
        const add = Math.floor(Math.random() * 18) - 9;
        const target = tens + other + add;
        return {
          question: `Start at ${tens}, hop ${other - tens}, then hop ${add}. Where do you land?`,
          answer: target,
          explanation: `We began at ${tens}, jumped ${other - tens}, and then moved ${add} more.`,
        };
      },
    },
    {
      prompt() {
        const base = Math.floor(Math.random() * 40) + 30;
        const factor = [2, 3, 4][Math.floor(Math.random() * 3)];
        const answer = base * factor;
        return {
          question: `${base} groups of ${factor} equals...?`,
          answer,
          explanation: `${base} × ${factor} = ${answer}. Think of ${factor} stacks of ${base}.`,
        };
      },
    },
    {
      prompt() {
        const start = Math.floor(Math.random() * 500) + 200;
        const chunk = Math.floor(Math.random() * 80) + 20;
        const part = Math.floor(Math.random() * 30) + 10;
        const answer = start - chunk - part;
        return {
          question: `You have ${start} petals, share ${chunk}, then ${part} more. How many petals sparkle left?`,
          answer,
          explanation: `${start} − ${chunk} − ${part} = ${answer}.` ,
        };
      },
    },
    {
      prompt() {
        const base = Math.floor(Math.random() * 90) + 10;
        const toNearest = [10, 100][Math.floor(Math.random() * 2)];
        const answer = Math.round(base / toNearest) * toNearest;
        return {
          question: `Round ${base} to the nearest ${toNearest}.`,
          answer,
          explanation: `Check which multiple of ${toNearest} is closest to ${base}.`,
        };
      },
    },
  ];

  let currentAnswer = null;
  let explanation = '';

  function buildOptions(correct) {
    const options = new Set([correct]);
    while (options.size < 4) {
      const wiggle = Math.floor(Math.random() * 20) - 10;
      options.add(correct + wiggle);
    }
    return Array.from(options).sort(() => Math.random() - 0.5);
  }

  function renderOptions(options) {
    optionsEl.innerHTML = '';
    options.forEach((option) => {
      const item = document.createElement('li');
      item.textContent = option;
      item.tabIndex = 0;
      item.setAttribute('role', 'button');
      item.addEventListener('click', () => checkAnswer(option));
      item.addEventListener('keypress', (event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          checkAnswer(option);
        }
      });
      optionsEl.appendChild(item);
    });
  }

  function checkAnswer(option) {
    if (option === currentAnswer) {
      feedbackEl.textContent = `Yes! ${explanation}`;
      feedbackEl.style.color = '#2dd8b5';
      stars.add();
      setTimeout(loadChallenge, 1200);
    } else {
      feedbackEl.textContent = `Close! Try thinking about ${explanation.toLowerCase()}`;
      feedbackEl.style.color = '#f6529d';
    }
  }

  function loadChallenge() {
    const chosen = templates[Math.floor(Math.random() * templates.length)].prompt();
    currentAnswer = chosen.answer;
    explanation = chosen.explanation;
    questionEl.textContent = chosen.question;
    feedbackEl.textContent = '';
    feedbackEl.style.color = '';
    renderOptions(buildOptions(chosen.answer));
  }

  newBtn.addEventListener('click', loadChallenge);
  loadChallenge();

  return { loadChallenge };
})();

// Long Division Lab
const longDivision = (() => {
  const divisorEl = document.getElementById('ldDivisor');
  const dividendEl = document.getElementById('ldDividend');
  const quotientEl = document.getElementById('ldQuotient');
  const currentEl = document.getElementById('ldCurrent');
  const remainderEl = document.getElementById('ldRemainder');
  const hintEl = document.getElementById('ldHint');
  const form = document.getElementById('ldForm');
  const input = document.getElementById('ldInput');
  const newBtn = document.getElementById('ldNew');

  const state = {
    divisor: 0,
    dividendDigits: [],
    processed: 0,
    currentValue: 0,
    quotientDigits: [],
    remainder: 0,
    finished: false,
  };

  function choosePuzzle() {
    state.divisor = Math.floor(Math.random() * 7) + 3; // 3 - 9
    const digits = Math.floor(Math.random() * 2) + 3; // 3 or 4 digits
    const min = 10 ** (digits - 1);
    const max = 10 ** digits - 1;
    const dividend = Math.floor(Math.random() * (max - min + 1)) + min;
    state.dividendDigits = dividend.toString().split('').map(Number);
    state.processed = 1;
    state.currentValue = state.dividendDigits[0];
    while (state.currentValue < state.divisor && state.processed < state.dividendDigits.length) {
      state.currentValue = state.currentValue * 10 + state.dividendDigits[state.processed];
      state.processed += 1;
    }
    state.quotientDigits = [];
    state.remainder = 0;
    state.finished = false;

    divisorEl.textContent = state.divisor;
    dividendEl.textContent = state.dividendDigits.join('');
    quotientEl.textContent = '—';
    currentEl.textContent = state.currentValue;
    remainderEl.textContent = '0';
    hintEl.style.color = '#2a1b3d';
    hintEl.textContent = `How many times does ${state.divisor} fit into ${state.currentValue}?`;
    input.value = '';
    input.disabled = false;
    input.focus();
  }

  function updateDisplays() {
    quotientEl.textContent = state.quotientDigits.length
      ? state.quotientDigits.join('')
      : '—';
    currentEl.textContent = state.currentValue;
    remainderEl.textContent = state.remainder;
  }

  function finishPuzzle() {
    state.finished = true;
    hintEl.textContent = `Great job! Quotient ${state.quotientDigits.join('')} with remainder ${state.remainder}.`;
    hintEl.style.color = '#2dd8b5';
    stars.add(2);
    input.value = '';
    input.disabled = true;
    setTimeout(() => {
      input.disabled = false;
      choosePuzzle();
    }, 2500);
  }

  function prepareNextStep(remainder) {
    state.remainder = remainder;
    if (state.processed < state.dividendDigits.length) {
      const nextDigit = state.dividendDigits[state.processed];
      state.processed += 1;
      state.currentValue = remainder * 10 + nextDigit;
      if (state.currentValue < state.divisor) {
        hintEl.textContent = `Bring down ${nextDigit}. ${state.currentValue} is smaller than ${state.divisor}, so place a 0 in the quotient.`;
      } else {
        hintEl.textContent = `Bring down ${nextDigit}. Now how many ${state.divisor}s fit into ${state.currentValue}?`;
      }
    } else {
      state.currentValue = remainder;
      if (state.currentValue < state.divisor) {
        finishPuzzle();
        return;
      }
      hintEl.textContent = `Almost there! How many ${state.divisor}s fit into ${state.currentValue}?`;
    }
    updateDisplays();
    input.value = '';
    input.focus();
  }

  form.addEventListener('submit', (event) => {
    event.preventDefault();
    if (state.finished) return;
    const value = Number.parseInt(input.value, 10);
    if (Number.isNaN(value) || value < 0 || value > 9) {
      hintEl.textContent = 'Try a digit between 0 and 9.';
      hintEl.style.color = '#f6529d';
      return;
    }

    const product = value * state.divisor;
    if (product > state.currentValue) {
      hintEl.textContent = `${value} is too big. ${state.divisor} × ${value} = ${product}, which is more than ${state.currentValue}.`;
      hintEl.style.color = '#f6529d';
      return;
    }

    const nextValue = state.currentValue - product;
    if ((value + 1) * state.divisor <= state.currentValue && state.currentValue !== 0) {
      hintEl.textContent = `Try a little higher. ${state.divisor} × ${value + 1} is ${state.divisor * (value + 1)}.`;
      hintEl.style.color = '#f6529d';
      return;
    }

    state.quotientDigits.push(value);
    state.remainder = nextValue;
    hintEl.style.color = '#2a1b3d';
    hintEl.textContent = `${state.divisor} × ${value} = ${product}. Subtract to get ${nextValue}.`;
    updateDisplays();

    if (state.processed >= state.dividendDigits.length && nextValue < state.divisor) {
      finishPuzzle();
      return;
    }
    prepareNextStep(nextValue);
  });

  newBtn.addEventListener('click', () => {
    input.disabled = false;
    choosePuzzle();
  });

  choosePuzzle();
  return { choosePuzzle };
})();

// Decimal Discovery River
const decimalExplorer = (() => {
  const targetEl = document.getElementById('decTarget');
  const slider = document.getElementById('decSlider');
  const guessEl = document.getElementById('decGuess');
  const feedbackEl = document.getElementById('decFeedback');
  const factEl = document.getElementById('decFact');
  const checkBtn = document.getElementById('decCheck');
  const newBtn = document.getElementById('decNew');

  const facts = [
    (value) => {
      const formatted = value.toFixed(2);
      return `${formatted} means ${Math.round(value * 10)} tenth(s).`;
    },
    (value) => {
      const formatted = value.toFixed(2);
      return `As a fraction, ${formatted} is ${Math.round(value * 100)}/100.`;
    },
    () => 'Decimals use place value: tenths, hundredths, then thousandths!',
    (value) => `If you double ${value.toFixed(2)}, you get ${(value * 2).toFixed(2)}.`,
  ];

  let target = 0;

  function updateSliderLabel() {
    const guess = slider.value / 100;
    guessEl.textContent = guess.toFixed(2);
  }

  function newQuest() {
    target = (Math.floor(Math.random() * 900) + 100) / 100; // between 1.00 and 9.99
    targetEl.textContent = target.toFixed(2);
    feedbackEl.textContent = '';
    feedbackEl.style.color = '';
    slider.value = Math.floor(Math.random() * 1001);
    updateSliderLabel();
    factEl.textContent = facts[Math.floor(Math.random() * facts.length)](target);
  }

  slider.addEventListener('input', updateSliderLabel);

  checkBtn.addEventListener('click', () => {
    const guess = slider.value / 100;
    const difference = Math.abs(target - guess);
    if (difference < 0.05) {
      feedbackEl.textContent = `Splash-tastic! You were within ${difference.toFixed(2)} of the target.`;
      feedbackEl.style.color = '#2dd8b5';
      stars.add();
    } else {
      feedbackEl.textContent = `You're ${difference.toFixed(2)} away. Try nudging the slider.`;
      feedbackEl.style.color = '#f6529d';
    }
  });

  newBtn.addEventListener('click', newQuest);
  newQuest();
  return { newQuest };
})();

// Accessibility helpers
['nsNew', 'ldNew', 'decNew'].forEach((id) => {
  const button = document.getElementById(id);
  button.addEventListener('keypress', (event) => {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      button.click();
    }
  });
});

// Idle sparkle bursts to keep attention
setInterval(() => {
  if (document.hidden) return;
  celebration.launch(4);
}, 12000);
