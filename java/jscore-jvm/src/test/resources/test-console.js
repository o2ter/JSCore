// Test script for console logging functionality
var consoleMessages = [];

// Override console to capture messages (if possible)
if (typeof console !== 'undefined') {
    console.log('Testing info message');
    console.error('Testing error message');
    console.warn = console.warn || console.log;
    console.warn('Testing warning message');
}

// Test various data types
console.log('String message');
console.log(123);
console.log(true);
console.log({key: 'value'});
console.log([1, 2, 3]);

'Console logging test completed';