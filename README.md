# Overview

This is an addon fix for window click through in transparent regions that was broken in electron 7.0.0beta5
https://github.com/electron/electron/issues/23042#issuecomment-721474777

By default, a borderless `NSWindow` will register clicks in opaque regions AND pass clicks through in transparent regions UNLESS you set `ignoresMouseEvents` at which point all clicks register, regardless of colour, or all clicks pass through. 

At some point in electron 7, `new BrowserWindow` started calling calling the harmless seeming `setIgnoreMouseEvents: NO` method, which forever disables transparent click through for the new window. 

This add-on fixes the problem by patching `setIgnoreMouseEvents` to be a no-op for ALL `NSWindow`s. It also adds a function `MakeWindowIgnoreMouseEvents()` which calls the unpatched `setIgnoreMouseEvents: YES`.

# Usage

Call `InstallClickThroughPatch()` before the `new BrowserWindow` you want to have the default transparent clickthrough behaviour. Call `MakeWindowIgnoreMouseEvents(win.getNativeWindowHandle())` on any `BrowserWindow` on which you want to all clicks to pass through.

# Future improvements

Hopefully chromium (I guess it's chromium) will stop doing `setIgnoreMouseEvents: NO` on its windows and this add-on will become obsolete.
Failing that, I don't like the indiscriminate way the code disables `setIgnoreMouseEvents` for all windows, nor the fact that `setIgnoreMouseEvents: NO` becomes completely unreachable.

Ideally the API would be just this:

`DisableSetIgnoreMouseEventsForTheNextWindowToBeCreated()` (this "flag-style" API is necessary because by the time we get the `BrowserWindow` it's too late to apply the patch, the damage has been done). With this implementation you would be free to call `BrowswerWindow.setIgnoreMouseEvents` on other windows for no or full click through.

This cleaner approach would require dynamically subclassing the incoming `NSWindow`, making `setIgnoreMouseEvents` a no-op, but I haven't had time to implement and test this.

More info in this SO answer, and take note of the comment in which the surprising tri-state `ignoresMouseEvents` boolean is explained.
https://stackoverflow.com/a/29451199/22147
