let deferredPrompt;

// Capture the beforeinstallprompt event to trigger custom prompt
window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault();
  deferredPrompt = e;

  // Show a manual install prompt
  setTimeout(() => {
    const userAccepted = confirm("Install Tashil App for faster access?");
    if (userAccepted && deferredPrompt) {
      deferredPrompt.prompt();
      deferredPrompt.userChoice.then((choiceResult) => {
        if (choiceResult.outcome === 'accepted') {
          console.log('User accepted the install prompt');
        } else {
          console.log('User dismissed the install prompt');
        }
        deferredPrompt = null;
      });
    }
  }, 2000);
});