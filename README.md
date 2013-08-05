Cupid
=====

Cupid is a debugging shim for Love2d.

Features
--------

* Developer console, displays print messages and executes lua.
* Game error detection and recovery.
* Can render a physics debug layer.
* Reload game sourcecode on the fly automaticly.


Installing
----------

* Copy the `cupid.lua` file to your project directory.
* Create a `conf.lua` file if you don't already have one.
* Add `require("cupid")` to the top of your `conf.lua`.


Use
---

While your game is running, press tilde ( ~ ) to activate the
console.  Print commands will show here.  Type `reload` to 
reload your game.

Automatic Reloading
-------------------

By default cupid will monitor all .lua files in the project directory, scanning it every so often.  It's somewhat more efficient to turn this off and use UP commands.  The remote module listens for console commands on UDP port 10137.

This command works well:

`watchmedo-2.7 shell-command --command='echo reload | nc -u localhost 10173' .`
 

License
-------

Same as Love2D.
