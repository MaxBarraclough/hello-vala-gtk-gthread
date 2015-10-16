using Gtk;
using Gdk; // For Gdk.threads_add_timeout_seconds
// using Posix;


// Intended to be run in a thread/context other than the main GUI thread
// as it blocks the thread
// For our thread-pool we'll need an ordinary function, not a member-function (right?)
void doSleepyAdjustmentSequenceForSlider(Scale slider, ulong durationInSeconds) {
      print("Thread executing: Now to sleep...\n");
      Thread.usleep(durationInSeconds * 1000 * 1000);
      print("Thread executing: Now to call 'invoke'\n");

//  Gdk.threads_enter(); // DEPRECATED synchronisation machinery
//  this.slider.adjustment.value = 63;
//  Gdk.threads_leave();

// default() gives correct context+thread given we don't explicitly provide a main loop
// http://valadoc.org/#!api=glib-2.0/GLib.MainContext.@default
      GLib.MainContext.default().invoke(
         () => { slider.adjustment.value = durationInSeconds;
                 return GLib.Source.REMOVE;
         }       // don't return CONTINUE or we'll infinite-loop
         /* , GLib.Priority.DEFAULT /**/);

///// this.slider.adjustment.value = 74; // UNSAFE! wrong thread!

      print("Thread executing: Now to return (this kills the thread / frees up the pool)\n");

      // Here, Thread.exit is equivalent to return
      return;
}

class SUPair {
  public Scale s;
  public ulong u;

  public SUPair(Scale sArg, ulong uArg) {
    this.s = sArg;
    this.u = uArg;
  }
}

void doSleepyAdjustmentSequenceForSliderProxy(SUPair p) {
  doSleepyAdjustmentSequenceForSlider( p.s, p.u );
}


//      GLib.MainContext.default().invoke( (owned)a /*, DEFAULT /**/); // accepts a nullary function returning bool
//      // because we use (owned), now a == null. This is roughly equivalent to doing an in-place lambda.
//      // See http://stackoverflow.com/a/16697408 : be careful passing delegates


// If threadPool were local, it would be destroyed as it went out of scope,
// which would block the main thread. To avoid this, we just make it global.
ThreadPool<SUPair> threadPool;
// can't be initialised here: constructor is not only constant, it also might throw

public class SyncSample : Gtk.Window {
   private SpinButton spin_box;
//  private Scale slider; // we can just keep this local

   public SyncSample() {
      this.title           = "Enter your age";
      this.window_position = WindowPosition.CENTER;
      this.destroy.connect(Gtk.main_quit);
      set_default_size(300, 20);

      this.spin_box = new SpinButton.with_range(0, 130, 1);
      Scale slider = new Scale.with_range(Orientation.HORIZONTAL, 0, 130, 1);

      spin_box.adjustment.value_changed.connect( () => {
                                                   slider.adjustment.value = spin_box.adjustment.value;
                                                });

      slider.adjustment.value_changed.connect( () => {
                                                 spin_box.adjustment.value = slider.adjustment.value;
                                              });

      spin_box.adjustment.value = 1; // Set initial value

      { // We won't use this with our thread-pool, but let's do it anyway
        // Gets number of *cores*, not processors! www.valadoc.org/#!api=glib-2.0/GLib.get_num_processors
        uint numCores = get_num_processors();   // returns uint
        // Can't use 'const': like in C#, Vala interprets 'const' to mean 'compile-time constant'

        GLib.assert( numCores >= 1 );

        print("We have %u cores on this machine\n", numCores);
      }

/////////////////////// APPROACH 1: Manually spawn a thread ///////////////////////
// After 9 seconds, assign 9
if(true)
{
// var myOtherThread =
  new Thread<int> /*.try*/ ("MyThread",  () => {
      doSleepyAdjustmentSequenceForSlider(slider,9);
      return 0; } ); // Thread func. must return int

// Bad idea! Blocking here hangs the GUI. Let the thread run in the background.
// int threadRet = myOtherThread.join(); print("Thread returned: %d\n", threadRet);
}

/////////////////////// APPROACH 2: Configure a GLib 'timer' ///////////////////////
// This is the correct way to program a delayed event
// After 7 seconds, assign 7
if(true)
{
      /* var eventSourceId = */ threads_add_timeout_seconds( 7, () => { 
//      No need to wrap in invoke: timeouts already handled by correct thread
//      GLib.MainContext.default().invoke( () => {
          slider.adjustment.value = 7; // return GLib.Source.REMOVE;
//      } );
        return GLib.Source.REMOVE;
      } );
}

/////////////////////// APPROACH 3: Spawn a thread using a GLib thread-pool ///////////////////////
// After 5 seconds, assign 5
// See http://valadoc.org/#!api=glib-2.0/GLib.ThreadPool
// https://developer.gnome.org/glib/stable/glib-Thread-Pools.html#g-thread-pool-new
if(true)
{
  try {
      /*ThreadPool<Scale>*/ threadPool = new ThreadPool<SUPair>.with_owned_data(
        (ThreadPoolFunc<SUPair>)doSleepyAdjustmentSequenceForSliderProxy, // Threads run this when we 'add' a task
	-1,     // Limit to how many threads the pool should have: just one will do for us.
	// Use -1 to indicate 'no limit'
        false); // Configure exclusiveness to false: we don't mind sharing threads between pools,
                // and we don't need all the threads to be spawned upfront: lazy spawning is fine

      // Start doing actual work with the (previously unoccupied) pool, using the arg we specify
      threadPool.add( new SUPair( slider, 5 ) );
  } catch(ThreadError e) {
    GLib.stderr.printf("ThreadError encountered. Message: <<%s>>\n", e.message);
  }
}

      var hbox = new Box(Orientation.HORIZONTAL, 5);
      hbox.homogeneous = true;
      hbox.add(spin_box);
      hbox.add(slider);
      add(hbox);
   }

   public static int main(string[] args) {
      Gtk.init(ref args);

      var window = new SyncSample();
      window.show_all();

      // GLib.static_assert( 1 == 2 ); // Must use from inside a function
      // Fails at compile time, in the C compiler, not valac

      Gtk.main();
      return 0; // == Posix.EXIT_SUCCESS;
   }
}

