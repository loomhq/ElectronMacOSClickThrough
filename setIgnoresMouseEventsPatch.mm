#include <napi.h>
#include <stdio.h>
#include <string.h>
#import <AppKit/AppKit.h>

#include <objc/runtime.h>
#include <objc/message.h>

// simple shim to conditionally disable setIgnoresMouseEvents so that it doesn't
// destroy our transparent window click-thru-ability
typedef void (*setIgnoresMouseEventsType)(NSWindow*, SEL, BOOL);
static setIgnoresMouseEventsType oldSetIgnoresMouseEvents;


// See the comment on this answer that says NSWindow.ignoresMouseEvents has THREE states
//   https://stackoverflow.com/a/29451199/22147
//    1. ignoresMouseEvents on transparent areas (the initial state)
//    2. ignores all events (YES)
//    3. does not ignore any events (NO)
// The first state is what we want for partial click through, and once setIgnoresMouseEvents
// has been called, you can never return to the initial state, so we turn calls to 
// setIgnoreMouseEvents into a no-op using a monkey patch.
static void setIgnoresMouseEvents(id self, SEL _cmd, BOOL ignores) {
  CGRect frame = [self frame];
  NSLog(@"setIgnoresMouseEvents: %@ - %@ to %i", self, NSStringFromRect(frame), ignores);

  // TODO: don't call on all windows.
  if (0) oldSetIgnoresMouseEvents(self, _cmd, ignores);
}

// Make a BrowserWindow completely transparent to clicks, so they pass through by calling
// setIgnoresMouseEvents: YES. This works even if the window is opaque. 
// There's probably a way to make this work from electron, but the current workaround patches
// out setIgnoresMouseEvents, hence the need for this.
static Napi::Value MakeWindowIgnoreMouseEvents(const Napi::CallbackInfo& info) {
  Napi::Env env = info.Env();

  if (info.Length() != 1) {
    Napi::Error::New(env, "Wrong number of arguments. Expected: (viewHandle)")
        .ThrowAsJavaScriptException();
    return env.Undefined();
  }

  if (!info[0].IsBuffer()) {
     Napi::TypeError::New(env, "First argument must be a Buffer").ThrowAsJavaScriptException();
     return env.Undefined();
  }

  NSView* view = nil;
  if (info[0].As<Napi::Buffer<uint8_t>>().Length() != sizeof(view)) {
    Napi::TypeError::New(env, "Buffer must contain correct pointer size").ThrowAsJavaScriptException();
    return env.Undefined();
  }

  Napi::Buffer<uint8_t> bytes = info[0].As<Napi::Buffer<uint8_t>>();

  view = *reinterpret_cast<NSView**>(bytes.Data());

  NSWindow *win = view.window;
  // NOTE: calling the unswizzled version
  oldSetIgnoresMouseEvents(win, @selector(setIgnoresMouseEvents:), YES);

  return env.Undefined();
}

// as an addon, this is called at require('bindings')('yourAddOn') time
// this is early enough in test app.
// which means this could equally be called by Init() without constructor magic
static void swizzle() {
    fprintf(stderr, "Swizzling NSWindow\n");
    id cls = objc_getClass("NSWindow");
    oldSetIgnoresMouseEvents = (setIgnoresMouseEventsType)method_setImplementation(class_getInstanceMethod(cls, @selector(setIgnoresMouseEvents:)), (IMP)setIgnoresMouseEvents);
    if (!oldSetIgnoresMouseEvents) fprintf(stderr, "[!] WARNING: NSWindow swizzle failed\n");
}

static Napi::Value InstallClickThroughPatch(const Napi::CallbackInfo& info) {
  swizzle();
  return info.Env().Undefined();
}

static Napi::Object Init(Napi::Env env, Napi::Object exports) {
  exports["InstallClickThroughPatch"] = Napi::Function::New(env, InstallClickThroughPatch);
  exports["MakeWindowIgnoreMouseEvents"] = Napi::Function::New(env, MakeWindowIgnoreMouseEvents);
  return exports;
}

NODE_API_MODULE(NODE_GYP_MODULE_NAME, Init)
