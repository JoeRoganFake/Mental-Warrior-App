import 'dart:math';

class Quote {
  final String text;
  final String author;

  Quote({required this.text, required this.author});
}

class QuoteService {
  final List<Quote> quotes = [
    Quote(
      text: "Discipline is the bridge between goals and accomplishment.",
      author: "Jim Rohn",
    ),
    Quote(
      text: "The only way to do great work is to love what you do.",
      author: "Steve Jobs",
    ),
    Quote(
      text: "Success is the sum of small efforts, repeated day in and day out.",
      author: "Robert Collier",
    ),
    Quote(
      text: "The pain you feel today will be the strength you feel tomorrow.",
      author: "Unknown",
    ),
    Quote(
      text: "Do something today that your future self will thank you for.",
      author: "Unknown",
    ),
    Quote(
      text: "Success doesn't just find you. You have to go out and get it.",
      author: "Unknown",
    ),
    Quote(
      text: "The key to success is to focus on goals, not obstacles.",
      author: "Unknown",
    ),
    Quote(
      text: "It always seems impossible until it's done.",
      author: "Nelson Mandela",
    ),
    Quote(
      text:
          "You don’t have to be great to start, but you have to start to be great.",
      author: "Zig Ziglar",
    ),
    Quote(
      text:
          "Discipline is choosing between what you want now and what you want most.",
      author: "Abraham Lincoln",
    ),
    Quote(
      text: "Small daily improvements over time lead to stunning results.",
      author: "Robin Sharma",
    ),
    Quote(
      text: "The future depends on what we do in the present.",
      author: "Mahatma Gandhi",
    ),
    Quote(
      text: "The way to get started is to quit talking and begin doing.",
      author: "Walt Disney",
    ),
    Quote(
      text: "The best way to predict the future is to create it.",
      author: "Peter Drucker",
    ),
    Quote(
      text: "Success is not in what you have, but who you are.",
      author: "Bo Bennett",
    ),
    Quote(
      text:
          "The only limit to our realization of tomorrow is our doubts of today.",
      author: "Franklin D. Roosevelt",
    ),
    Quote(
      text: "What we think, we become.",
      author: "Buddha",
    ),
    Quote(
      text: "It does not matter how slowly you go as long as you do not stop.",
      author: "Confucius",
    ),
    Quote(
      text: "Your limitation—it’s only your imagination.",
      author: "Unknown",
    ),
    Quote(
      text: "Push yourself, because no one else is going to do it for you.",
      author: "Unknown",
    ),
    Quote(
      text: "Great things never come from comfort zones.",
      author: "Unknown",
    ),
    Quote(
      text: "Dream it. Wish it. Do it.",
      author: "Unknown",
    ),
    Quote(
      text: "Success doesn’t just happen. It’s planned.",
      author: "Unknown",
    ),
    Quote(
      text: "Discipline is the foundation upon which all success is built.",
      author: "Jim Rohn",
    ),
    Quote(
      text: "The secret to getting ahead is getting started.",
      author: "Mark Twain",
    ),
    Quote(
      text: "Believe you can and you’re halfway there.",
      author: "Theodore Roosevelt",
    ),
    Quote(
      text: "Don’t stop when you’re tired. Stop when you’re done.",
      author: "Unknown",
    ),
    Quote(
      text:
          "The harder you work for something, the greater you’ll feel when you achieve it.",
      author: "Unknown",
    ),
    Quote(
      text:
          "Success is not the key to happiness. Happiness is the key to success.",
      author: "Albert Schweitzer",
    ),
    Quote(
      text:
          "The only way to achieve the impossible is to believe it is possible.",
      author: "Charles Kingsleigh",
    ),
    Quote(
      text:
          "Motivation is what gets you started. Habit is what keeps you going.",
      author: "Jim Ryun",
    ),
    Quote(
      text: "The mind is everything. What you think you become.",
      author: "Buddha",
    ),
    Quote(
      text: "Don’t wish for it. Work for it.",
      author: "Unknown",
    ),
    Quote(
      text: "If you want to achieve greatness stop asking for permission.",
      author: "Unknown",
    ),
    Quote(
      text: "Everything you need is already inside you.",
      author: "Unknown",
    ),
    Quote(
      text:
          "Your life does not get better by chance, it gets better by change.",
      author: "Jim Rohn",
    ),
    Quote(
      text: "Success is not for the chosen few, but for the few who choose it.",
      author: "Unknown",
    ),
    Quote(
      text: "Take the risk or lose the chance.",
      author: "Unknown",
    ),
    Quote(
      text: "Be stronger than your strongest excuse.",
      author: "Unknown",
    ),
    Quote(
      text: "Do what you can with all you have, wherever you are.",
      author: "Theodore Roosevelt",
    ),
    Quote(
      text: "A year from now you may wish you had started today.",
      author: "Karen Lamb",
    ),
    Quote(
      text: "Don’t wait for opportunity. Create it.",
      author: "Unknown",
    ),
    Quote(
      text: "Be a voice, not an echo.",
      author: "Unknown",
    ),
    Quote(
      text:
          "Stop being afraid of what could go wrong and think of what could go right.",
      author: "Unknown",
    ),
    Quote(
      text:
          "Success is not the absence of failure; it’s the persistence through failure.",
      author: "Arianna Huffington",
    ),
    Quote(
      text:
          "What you get by achieving your goals is not as important as what you become by achieving your goals.",
      author: "Zig Ziglar",
    ),
    Quote(
      text:
          "The best time to plant a tree was 20 years ago. The second best time is now.",
      author: "Chinese Proverb",
    ),
    Quote(
      text: "Failure is not the opposite of success; it’s part of success.",
      author: "Arianna Huffington",
    ),
    Quote(
      text:
          "If you want something you’ve never had, you must be willing to do something you’ve never done.",
      author: "Thomas Jefferson",
    ),
    Quote(
      text:
          "The difference between who you are and who you want to be is what you do.",
      author: "Unknown",
    ),
    // first 50
    Quote(
      text:
          "The greatest glory in living lies not in never falling, but in rising every time we fall.",
      author: "Nelson Mandela",
    ),
    Quote(
      text:
          "The purpose of life is not to be happy. It is to be useful, to be honorable, to be compassionate, to have it make some difference that you have lived and lived well.",
      author: "Ralph Waldo Emerson",
    ),
    Quote(
      text: "Life is what happens when you're busy making other plans.",
      author: "John Lennon",
    ),
    Quote(
      text:
          "In the end, we will remember not the words of our enemies, but the silence of our friends.",
      author: "Martin Luther King Jr.",
    ),
    Quote(
      text:
          "You will face many defeats in life, but never let yourself be defeated.",
      author: "Maya Angelou",
    ),
    Quote(
      text: "It is never too late to be what you might have been.",
      author: "George Eliot",
    ),
    Quote(
      text: "You miss 100% of the shots you don't take.",
      author: "Wayne Gretzky",
    ),
    Quote(
      text: "The only impossible journey is the one you never begin.",
      author: "Tony Robbins",
    ),
    Quote(
      text:
          "Don't judge each day by the harvest you reap but by the seeds that you plant.",
      author: "Robert Louis Stevenson",
    ),
    Quote(
      text: "It always seems impossible until it’s done.",
      author: "Nelson Mandela",
    ),
    Quote(
      text: "You can't use up creativity. The more you use, the more you have.",
      author: "Maya Angelou",
    ),
    Quote(
      text:
          "I can't change the direction of the wind, but I can adjust my sails to always reach my destination.",
      author: "Jimmy Dean",
    ),
    Quote(
      text:
          "What lies behind us and what lies before us are tiny matters compared to what lies within us.",
      author: "Ralph Waldo Emerson",
    ),
    Quote(
      text: "Believe you can and you're halfway there.",
      author: "Theodore Roosevelt",
    ),
    Quote(
      text:
          "Do not go where the path may lead, go instead where there is no path and leave a trail.",
      author: "Ralph Waldo Emerson",
    ),
    Quote(
      text: "It does not matter how slowly you go as long as you do not stop.",
      author: "Confucius",
    ),
    Quote(
      text:
          "Success is not how high you have climbed, but how you make a positive difference to the world.",
      author: "Roy T. Bennett",
    ),
    Quote(
      text:
          "Success usually comes to those who are too busy to be looking for it.",
      author: "Henry David Thoreau",
    ),
    Quote(
      text: "Don't watch the clock; do what it does. Keep going.",
      author: "Sam Levenson",
    ),
    Quote(
      text:
          "You don’t have to be great to start, but you have to start to be great.",
      author: "Zig Ziglar",
    ),
    Quote(
      text: "The best revenge is massive success.",
      author: "Frank Sinatra",
    ),
    Quote(
      text: "It is not length of life, but depth of life.",
      author: "Ralph Waldo Emerson",
    ),
    Quote(
      text: "Don't wait. The time will never be just right.",
      author: "Napoleon Hill",
    ),
    Quote(
      text: "Everything you can imagine is real.",
      author: "Pablo Picasso",
    ),
    Quote(
      text: "Start where you are. Use what you have. Do what you can.",
      author: "Arthur Ashe",
    ),
    Quote(
      text:
          "You are never too old to set another goal or to dream a new dream.",
      author: "C.S. Lewis",
    ),
    Quote(
      text: "The journey of a thousand miles begins with one step.",
      author: "Lao Tzu",
    ),
    Quote(
      text: "Time is what we want most, but what we use worst.",
      author: "William Penn",
    ),
    Quote(
      text:
          "If you want to live a happy life, tie it to a goal, not to people or things.",
      author: "Albert Einstein",
    ),
    Quote(
      text: "Success is not in what you have, but who you are.",
      author: "Bo Bennett",
    ),
    Quote(
      text: "Action is the foundational key to all success.",
      author: "Pablo Picasso",
    ),
    Quote(
      text: "The best way to get started is to quit talking and begin doing.",
      author: "Walt Disney",
    ),
    Quote(
      text: "You miss 100% of the shots you don't take.",
      author: "Wayne Gretzky",
    ),
    Quote(
      text: "Everything you've ever wanted is on the other side of fear.",
      author: "George Addair",
    ),
    Quote(
      text: "In order to succeed, we must first believe that we can.",
      author: "Nikos Kazantzakis",
    ),
    Quote(
      text: "Success is the sum of small efforts, repeated day in and day out.",
      author: "Robert Collier",
    ),
    Quote(
      text:
          "A goal is not always meant to be reached, it often serves simply as something to aim at.",
      author: "Bruce Lee",
    ),
    Quote(
      text: "Success is a journey, not a destination.",
      author: "Ben Sweetland",
    ),
    Quote(
      text:
          "You are never too old to set another goal or to dream a new dream.",
      author: "C.S. Lewis",
    ),
    Quote(
      text: "Failure is the condiment that gives success its flavor.",
      author: "Truman Capote",
    ),
    Quote(
      text:
          "Success is walking from failure to failure with no loss of enthusiasm.",
      author: "Winston Churchill",
    ),
    Quote(
      text: "We may encounter many defeats, but we must not be defeated.",
      author: "Maya Angelou",
    ),
    Quote(
      text: "There are no shortcuts to any place worth going.",
      author: "Beverly Sills",
    ),
    Quote(
      text:
          "Success is not the key to happiness. Happiness is the key to success.",
      author: "Albert Schweitzer",
    ),
    Quote(
      text: "The only way to do great work is to love what you do.",
      author: "Steve Jobs",
    ),
    Quote(
      text: "If you can dream it, you can do it.",
      author: "Walt Disney",
    ),
    Quote(
      text:
          "Success consists of going from failure to failure without loss of enthusiasm.",
      author: "Winston Churchill",
    ),
    Quote(
      text: "What we achieve inwardly will change outer reality.",
      author: "Plutarch",
    ),
    Quote(
      text: "Don’t wait. The time will never be just right.",
      author: "Napoleon Hill",
    ),
    Quote(
      text:
          "The only limit to our realization of tomorrow is our doubts of today.",
      author: "Franklin D. Roosevelt",
    ),
    Quote(
      text:
          "The road to success and the road to failure are almost exactly the same.",
      author: "Colin R. Davis",
    ),
// second 50
    Quote(
      text:
          "Success is not final, failure is not fatal: It is the courage to continue that counts.",
      author: "Winston Churchill",
    ),
    Quote(
      text: "It always seems impossible until it's done.",
      author: "Nelson Mandela",
    ),
    Quote(
      text: "Act as if what you do makes a difference. It does.",
      author: "William James",
    ),
    Quote(
      text: "The secret of getting ahead is getting started.",
      author: "Mark Twain",
    ),
    Quote(
      text:
          "Success is the ability to go from one failure to another with no loss of enthusiasm.",
      author: "Winston Churchill",
    ),
    Quote(
      text:
          "Success usually comes to those who are too busy to be looking for it.",
      author: "Henry David Thoreau",
    ),
    Quote(
      text: "Don’t watch the clock; do what it does. Keep going.",
      author: "Sam Levenson",
    ),
    Quote(
      text:
          "You don’t have to be great to start, but you have to start to be great.",
      author: "Zig Ziglar",
    ),
    Quote(
      text: "Success is not in what you have, but who you are.",
      author: "Bo Bennett",
    ),
    Quote(
      text: "A journey of a thousand miles begins with a single step.",
      author: "Lao Tzu",
    ),
    Quote(
      text: "The best way to predict the future is to create it.",
      author: "Peter Drucker",
    ),
    Quote(
      text:
          "The harder you work for something, the greater you’ll feel when you achieve it.",
      author: "Unknown",
    ),
    Quote(
      text: "Don’t stop when you’re tired. Stop when you’re done.",
      author: "Unknown",
    ),
    Quote(
      text: "Success doesn’t just find you. You have to go out and get it.",
      author: "Unknown",
    ),
    Quote(
      text:
          "Discipline is choosing between what you want now and what you want most.",
      author: "Abraham Lincoln",
    ),
    Quote(
      text:
          "The only way to achieve the impossible is to believe it is possible.",
      author: "Charles Kingsleigh",
    ),
    Quote(
      text:
          "The only place where success comes before work is in the dictionary.",
      author: "Vidal Sassoon",
    ),
    Quote(
      text: "You don’t have to be perfect to be amazing.",
      author: "Unknown",
    ),
    Quote(
      text: "Success is not in what you have, but who you are.",
      author: "Bo Bennett",
    ),
    Quote(
      text: "Start where you are. Use what you have. Do what you can.",
      author: "Arthur Ashe",
    ),
    Quote(
      text: "Nothing will work unless you do.",
      author: "Maya Angelou",
    ),
    Quote(
      text:
          "Success doesn’t come from what you do occasionally, it comes from what you do consistently.",
      author: "Marie Forleo",
    ),
    Quote(
      text: "Don’t wish for it. Work for it.",
      author: "Unknown",
    ),
    Quote(
      text: "The harder you work, the luckier you get.",
      author: "Gary Player",
    ),
    Quote(
      text:
          "To be successful, you must accept all challenges that come your way. You can’t just accept the ones you like.",
      author: "Mike Gafka",
    ),
    Quote(
      text: "It’s not whether you get knocked down, it’s whether you get up.",
      author: "Vince Lombardi",
    ),
    Quote(
      text:
          "Do not wait to strike till the iron is hot, but make it hot by striking.",
      author: "William Butler Yeats",
    ),
    Quote(
      text: "Everything you can imagine is real.",
      author: "Pablo Picasso",
    ),
    Quote(
      text: "Work hard in silence, let your success be your noise.",
      author: "Frank Ocean",
    ),
    Quote(
      text: "Don’t stop when you’re tired. Stop when you’re done.",
      author: "Unknown",
    ),
    Quote(
      text: "Success is a journey, not a destination.",
      author: "Ben Sweetland",
    ),
    Quote(
      text:
          "The only limit to our realization of tomorrow is our doubts of today.",
      author: "Franklin D. Roosevelt",
    ),
    Quote(
      text: "Success is the sum of small efforts, repeated day in and day out.",
      author: "Robert Collier",
    ),
    Quote(
      text: "It does not matter how slowly you go as long as you do not stop.",
      author: "Confucius",
    ),
    Quote(
      text:
          "Success is not the key to happiness. Happiness is the key to success.",
      author: "Albert Schweitzer",
    ),
    Quote(
      text: "The best revenge is massive success.",
      author: "Frank Sinatra",
    ),
    Quote(
      text: "Don’t wait. The time will never be just right.",
      author: "Napoleon Hill",
    ),
    
    Quote(
      text: "Everything you need is already inside you.",
      author: "Unknown",
    ),
    Quote(
      text:
          "You don’t have to be great to start, but you have to start to be great.",
      author: "Zig Ziglar",
    ),
    Quote(
      text: "Take action, and the universe will respond to your actions.",
      author: "Unknown",
    ),
    Quote(
      text:
          "The best time to plant a tree was 20 years ago. The second best time is now.",
      author: "Chinese Proverb",
    ),
    Quote(
      text: "The only way to do great work is to love what you do.",
      author: "Steve Jobs",
    ),
    Quote(
      text:
          "Failure is simply the opportunity to begin again, this time more intelligently.",
      author: "Henry Ford",
    ),
    Quote(
      text: "A goal is a dream with a deadline.",
      author: "Napoleon Hill",
    ),
    Quote(
      text: "Life is what happens when you’re busy making other plans.",
      author: "John Lennon",
    ),
    Quote(
      text: "Your limitation—it’s only your imagination.",
      author: "Unknown",
    ),
    Quote(
      text: "Push yourself, because no one else is going to do it for you.",
      author: "Unknown",
    ),
    //150
    Quote(
      text:
          "The only way to achieve the impossible is to believe it is possible.",
      author: "Charles Kingsleigh",
    ),
    Quote(
      text: "Discipline is the bridge between goals and accomplishment.",
      author: "Jim Rohn",
    ),
    Quote(
      text:
          "The future belongs to those who believe in the beauty of their dreams.",
      author: "Eleanor Roosevelt",
    ),
    Quote(
      text: "Don't limit your challenges, challenge your limits.",
      author: "Unknown",
    ),
    Quote(
      text: "Success is the sum of small efforts, repeated day in and day out.",
      author: "Robert Collier",
    ),
    Quote(
      text: "Small daily improvements over time lead to stunning results.",
      author: "Robin Sharma",
    ),
    Quote(
      text: "Don’t wait. The time will never be just right.",
      author: "Napoleon Hill",
    ),
    Quote(
      text: "Everything you can imagine is real.",
      author: "Pablo Picasso",
    ),
    Quote(
      text:
          "You don’t have to be great to start, but you have to start to be great.",
      author: "Zig Ziglar",
    ),
    Quote(
      text:
          "Do not go where the path may lead, go instead where there is no path and leave a trail.",
      author: "Ralph Waldo Emerson",
    ),
    Quote(
      text: "I find that the harder I work, the more luck I seem to have.",
      author: "Thomas Jefferson",
    ),
    Quote(
      text: "Do what you can with all you have, wherever you are.",
      author: "Theodore Roosevelt",
    ),
    Quote(
      text: "Opportunities don't happen, you create them.",
      author: "Chris Grosser",
    ),
    Quote(
      text: "The best way to predict your future is to create it.",
      author: "Abraham Lincoln",
    ),
    Quote(
      text: "A person who never made a mistake never tried anything new.",
      author: "Albert Einstein",
    ),
    Quote(
      text:
          "Hardships often prepare ordinary people for an extraordinary destiny.",
      author: "C.S. Lewis",
    ),
    Quote(
      text:
          "The only place where success comes before work is in the dictionary.",
      author: "Vidal Sassoon",
    ),
    Quote(
      text:
          "Success is not final, failure is not fatal: It is the courage to continue that counts.",
      author: "Winston Churchill",
    ),
    Quote(
      text:
          "Great things are not done by impulse, but by a series of small things brought together.",
      author: "Vincent Van Gogh",
    ),
    Quote(
      text:
          "Perseverance is not a long race; it is many short races one after the other.",
      author: "Walter Elliot",
    ),
    Quote(
      text: "With hard work and effort, you can achieve anything.",
      author: "Unknown",
    ),
    Quote(
      text: "The only way to do great work is to love what you do.",
      author: "Steve Jobs",
    ),
    Quote(
      text:
          "The only limit to our realization of tomorrow is our doubts of today.",
      author: "Franklin D. Roosevelt",
    ),
    Quote(
      text: "Success is not in what you have, but who you are.",
      author: "Bo Bennett",
    ),
    Quote(
      text: "If you want to achieve greatness stop asking for permission.",
      author: "Unknown",
    ),
    Quote(
      text:
          "If you are not willing to risk the usual, you will have to settle for the ordinary.",
      author: "Jim Rohn",
    ),
    Quote(
      text:
          "Don’t be pushed around by the fears in your mind. Be led by the dreams in your heart.",
      author: "Roy T. Bennett",
    ),
    Quote(
      text: "Success is a journey, not a destination.",
      author: "Ben Sweetland",
    ),
    Quote(
      text: "It’s hard to beat a person who never gives up.",
      author: "Babe Ruth",
    ),
    Quote(
      text:
          "Keep your face always toward the sunshine—and shadows will fall behind you.",
      author: "Walt Whitman",
    ),
    Quote(
      text: "You miss 100% of the shots you don’t take.",
      author: "Wayne Gretzky",
    ),
    Quote(
      text:
          "Success is walking from failure to failure with no loss of enthusiasm.",
      author: "Winston Churchill",
    ),
    Quote(
      text: "Don’t stop when you’re tired. Stop when you’re done.",
      author: "Unknown",
    ),
    Quote(
      text:
          "The future belongs to those who believe in the beauty of their dreams.",
      author: "Eleanor Roosevelt",
    ),
    Quote(
      text:
          "Success doesn’t come from what you do occasionally, it comes from what you do consistently.",
      author: "Marie Forleo",
    ),
    Quote(
      text: "The way to get started is to quit talking and begin doing.",
      author: "Walt Disney",
    ),
    Quote(
      text:
          "Success is not the key to happiness. Happiness is the key to success.",
      author: "Albert Schweitzer",
    ),
    Quote(
      text: "Don't wish it were easier. Wish you were better.",
      author: "Jim Rohn",
    ),
    Quote(
      text: "If you can dream it, you can do it.",
      author: "Walt Disney",
    ),
    Quote(
      text: "Success is the sum of small efforts, repeated day in and day out.",
      author: "Robert Collier",
    ),
    Quote(
      text: "The only way to do great work is to love what you do.",
      author: "Steve Jobs",
    ),
    Quote(
      text: "Start where you are. Use what you have. Do what you can.",
      author: "Arthur Ashe",
    ),
    Quote(
      text:
          "The harder you work for something, the greater you’ll feel when you achieve it.",
      author: "Unknown",
    ),
    Quote(
      text:
          "Success is not the key to happiness. Happiness is the key to success.",
      author: "Albert Schweitzer",
    ),
    Quote(
      text: "Don’t stop when you’re tired. Stop when you’re done.",
      author: "Unknown",
    ),
    Quote(
      text:
          "Success doesn’t come from what you do occasionally, it comes from what you do consistently.",
      author: "Marie Forleo",
    ),
    Quote(
      text: "Everything you can imagine is real.",
      author: "Pablo Picasso",
    ),
    Quote(
      text: "You miss 100% of the shots you don’t take.",
      author: "Wayne Gretzky",
    ),
    //200
  ];

  // Store the daily quote
  Quote? _dailyQuote;
  DateTime? _lastQuoteDate;

  Quote getDailyQuote() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Generate a new quote if we don't have one yet or if it's a new day
    if (_dailyQuote == null ||
        _lastQuoteDate == null ||
        _lastQuoteDate != today) {
      _dailyQuote = quotes[Random().nextInt(quotes.length)];
      _lastQuoteDate = today;
    }

    return _dailyQuote!;
  }
}
