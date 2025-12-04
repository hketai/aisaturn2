import {
  format,
  isSameYear,
  fromUnixTime,
  formatDistanceToNow,
  differenceInDays,
} from 'date-fns';
import { tr } from 'date-fns/locale';

// Get current locale from document or default to 'en'
const getCurrentLocale = () => {
  const htmlLang = document.documentElement.lang || 'en';
  if (htmlLang.startsWith('tr')) {
    return tr;
  }
  return undefined; // Use default (English)
};

/**
 * Formats a Unix timestamp into a human-readable time format.
 * @param {number} time - Unix timestamp.
 * @param {string} [dateFormat='h:mm a'] - Desired format of the time.
 * @returns {string} Formatted time string.
 */
export const messageStamp = (time, dateFormat = 'h:mm a') => {
  const unixTime = fromUnixTime(time);
  return format(unixTime, dateFormat);
};

/**
 * Provides a formatted timestamp, adjusting the format based on the current year.
 * @param {number} time - Unix timestamp.
 * @param {string} [dateFormat='MMM d, yyyy'] - Desired date format.
 * @returns {string} Formatted date string.
 */
export const messageTimestamp = (time, dateFormat = 'MMM d, yyyy') => {
  const messageTime = fromUnixTime(time);
  const now = new Date();
  const messageDate = format(messageTime, dateFormat);
  if (!isSameYear(messageTime, now)) {
    return format(messageTime, 'LLL d y, h:mm a');
  }
  return messageDate;
};

/**
 * Converts a Unix timestamp to a relative time string (e.g., 3 hours ago).
 * @param {number} time - Unix timestamp.
 * @returns {string} Relative time string.
 */
export const dynamicTime = time => {
  const unixTime = fromUnixTime(time);
  const locale = getCurrentLocale();
  return formatDistanceToNow(unixTime, { addSuffix: true, locale });
};

/**
 * Formats a Unix timestamp into a specified date format.
 * @param {number} time - Unix timestamp.
 * @param {string} [dateFormat='MMM d, yyyy'] - Desired date format.
 * @returns {string} Formatted date string.
 */
export const dateFormat = (time, df = 'MMM d, yyyy') => {
  const unixTime = fromUnixTime(time);
  return format(unixTime, df);
};

/**
 * Converts a detailed time description into a shorter format, optionally appending 'ago'.
 * @param {string} time - Detailed time description (e.g., 'a minute ago').
 * @param {boolean} [withAgo=false] - Whether to append 'ago' to the result.
 * @returns {string} Shortened time description.
 */
export const shortTimestamp = (time, withAgo = false) => {
  // This function takes a time string and converts it to a short time string
  // with the following format: 1dk, 1sa, 1g, 1ay, 1y (Turkish) or 1m, 1h, 1d, 1mo, 1y (English)
  // The function also takes an optional boolean parameter withAgo
  // which will add the word "ago"/"önce" to the end of the time string

  const isTurkish = time.includes('önce') || time.includes('dakika') || time.includes('saat');
  const suffix = withAgo ? (isTurkish ? ' önce' : ' ago') : '';

  // English mappings
  const englishMappings = {
    'less than a minute ago': 'şimdi',
    'a minute ago': `1dk${suffix}`,
    'an hour ago': `1sa${suffix}`,
    'a day ago': `1g${suffix}`,
    'a month ago': `1ay${suffix}`,
    'a year ago': `1y${suffix}`,
  };

  // Turkish mappings
  const turkishMappings = {
    'bir dakikadan az önce': 'şimdi',
    'bir dakika önce': `1dk${suffix}`,
    '1 dakika önce': `1dk${suffix}`,
    'bir saat önce': `1sa${suffix}`,
    '1 saat önce': `1sa${suffix}`,
    'bir gün önce': `1g${suffix}`,
    '1 gün önce': `1g${suffix}`,
    'bir ay önce': `1ay${suffix}`,
    '1 ay önce': `1ay${suffix}`,
    'bir yıl önce': `1y${suffix}`,
    '1 yıl önce': `1y${suffix}`,
  };

  // Check if the time string is one of the specific cases
  if (englishMappings[time]) {
    return englishMappings[time];
  }
  if (turkishMappings[time]) {
    return turkishMappings[time];
  }

  // Handle Turkish time strings
  if (isTurkish) {
    const convertToShortTime = time
      .replace(/yaklaşık |neredeyse |/g, '')
      .replace(/ dakika önce/g, `dk${suffix}`)
      .replace(/ saat önce/g, `sa${suffix}`)
      .replace(/ gün önce/g, `g${suffix}`)
      .replace(/ ay önce/g, `ay${suffix}`)
      .replace(/ yıl önce/g, `y${suffix}`);
    return convertToShortTime;
  }

  // Handle English time strings
  const convertToShortTime = time
    .replace(/about|over|almost|/g, '')
    .replace(' minute ago', `dk${suffix}`)
    .replace(' minutes ago', `dk${suffix}`)
    .replace(' hour ago', `sa${suffix}`)
    .replace(' hours ago', `sa${suffix}`)
    .replace(' day ago', `g${suffix}`)
    .replace(' days ago', `g${suffix}`)
    .replace(' month ago', `ay${suffix}`)
    .replace(' months ago', `ay${suffix}`)
    .replace(' year ago', `y${suffix}`)
    .replace(' years ago', `y${suffix}`);
  return convertToShortTime;
};

/**
 * Calculates the difference in days between now and a given timestamp.
 * @param {Date} now - Current date/time.
 * @param {number} timestampInSeconds - Unix timestamp in seconds.
 * @returns {number} Number of days difference.
 */
export const getDayDifferenceFromNow = (now, timestampInSeconds) => {
  const date = new Date(timestampInSeconds * 1000);
  return differenceInDays(now, date);
};

/**
 * Checks if more than 24 hours have passed since a given timestamp.
 * Useful for determining if retry/refresh actions should be disabled.
 * @param {number} timestamp - Unix timestamp.
 * @returns {boolean} True if more than 24 hours have passed.
 */
export const hasOneDayPassed = timestamp => {
  if (!timestamp) return true; // Defensive check
  return getDayDifferenceFromNow(new Date(), timestamp) >= 1;
};
