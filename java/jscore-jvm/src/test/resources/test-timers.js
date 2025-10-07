// Test script for timer functionality
var timerResults = {
    timeoutExecuted: false,
    intervalCount: 0,
    intervalCleared: false
};

// Test setTimeout
setTimeout(function() {
    timerResults.timeoutExecuted = true;
    console.log('Timeout executed');
}, 50);

// Test setInterval and clearInterval
var intervalId = setInterval(function() {
    timerResults.intervalCount++;
    console.log('Interval tick: ' + timerResults.intervalCount);
    
    if (timerResults.intervalCount >= 3) {
        clearInterval(intervalId);
        timerResults.intervalCleared = true;
        console.log('Interval cleared');
    }
}, 25);

// Return results for verification
timerResults;