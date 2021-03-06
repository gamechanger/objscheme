//
// ObSGarbageCollector.m
// GameChanger
//
// Created by Kiril Savino on Tuesday, April 16, 2013
// Copyright 2013 GameChanger. All rights reserved.
//

#import "ObSGarbageCollector.h"
#import "ObjScheme.h"
#import "ObSCollectible.h"

@implementation ObSGarbageCollector

@synthesize synchronous=_synchronous;

typedef void (*DispatchFunction)(dispatch_queue_t, void (^block)(void));

- (id)initWithRoot:(ObSCollectible*)root {
  if ( self = [super init] ) {
    _synchronous = YES;
    _root = root;
    _collectibles = [[NSMutableSet alloc] init];
  }
  return self;
}

- (void)dealloc {
  _root = nil;
  [_collectibles release];
  _collectibles = nil;
  [super dealloc];
}

- (void)startTracking:(ObSCollectible*)collectible {
  [_collectibles addObject: collectible];
  collectible->_garbageCollector = self;
}

- (void)stopTracking:(ObSCollectible*)collectible {
  collectible->_garbageCollector = nil;
  [_collectibles removeObject: collectible];
}

- (void)mark:(ObSCollectible*)node reachable:(NSMutableSet*)reachable {
  // don't freak out on retain cycles, that's the point
  if ( [reachable containsObject: node] ) {
    return;
  }

  [reachable addObject: node];

  for ( ObSCollectible* child in [node children] ) {
    [self mark: child reachable: reachable];
  }
}

/**
 * This function deserves some discussion.
 *
 * First off, "garbage collection" in ObjScheme as of this writing
 * only pertains to scopes & things that retain scopes (e.g. Lambdas).
 *
 * To create a way to break retain cycles (which are a reality in Scheme because
 * Lambdas need to retain containing scopes, which need to retain said Lambdas)
 * we are just going to keep track of all the things of this nature, which we're
 * going to call Collectibles.  Collectibles are all to be registered with
 * a GarbageCollector, which basically just keeps a big ole list of them all.
 *
 * The GarbageCollector does, indeed, keep strong references to Collectibles!
 * The GarbageCollector also delegates to Collectibles the task of releasing
 * themselves from its grasp.  Collectibles are always aware of their GarbageCollector
 * (via a __weak reference), and they know they're retained by the GC.  So when
 * a [release] call to a Collectible would bring it to a retainCount of 1,
 * the Collectible will, before decrementing retain count, it asks to be released
 * from the GC.  This means that for Collectibles not part of retain clusters/cycles,
 * as soon as they'd otherwise be dealloc'ed, they still are, and the GC doesn't
 * extend their life.
 * Secondarily, this function basically exists to bust up those retain clusters.
 *
 * It does that in a 3-phase mark & sweep.
 * Phase 1:  Marking
 *    traverses down from the Root node, marking all of the Collectibles
 *    that are reachable via basic traversal.
 * Phase 2:  Sweeping
 *    finds the disjoint set of all Collectibles this GC knows about that are
 *    no longer reachable, and puts them in a (strongly retained) list.
 * Phase 3:  Cluster Busting
 *    now we tell all of the Collectibles to let go of their 'children', who
 *    are other Collectible nodes that they keep strong references to.
 *
 * The implicit "Phase 4" is that after all of that "letting go" is done,
 * each item in the Unreachable list should have a retain count of exactly 2:
 *  (1) the 'unreachable' list that we've just constructed to hold them, and
 *  (2) the GC's list itself.
 * When we finally release the 'unreachable' list, all of those Collectibles
 * should now de-register themselves from this GC, and subsequently die.
 *
 * TADA!!
 */
- (void)runGarbageCollection {
  //NSLog( @"ObjScheme Garbage collecting starting at %p (global is %p)", _root, [ObjScheme globalScope] );
  // mark stuff as reachable
  NSMutableSet* reachable = [[NSMutableSet alloc] initWithCapacity: [_collectibles count]];
  [self mark: _root reachable: reachable];

  /*
  if ( [reachable count] < 10 ) {
    NSLog( @"REACHABLE %@", reachable );
  } else {
    NSLog( @"too many reachable..." );
  }
  */

  DispatchFunction dispatch = _synchronous ? dispatch_sync : dispatch_async;

  dispatch(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      // sweep all the unreachable into a list
      NSMutableArray* unreachable = [[NSMutableArray alloc] initWithCapacity: [_collectibles count]];
      NSSet* collectibleCopy = [_collectibles copy]; // prevent mutation, but also don't allow any autorelease
      //NSLog( @"GC running with %d scopes", [collectibleCopy count] );
      //NSLog( @"Reachable: %d", [reachable count] );
      for ( ObSCollectible* collectible in collectibleCopy ) {
        if ( ! [reachable containsObject: collectible] ) {
          [unreachable addObject: collectible];
        }
      }
      [collectibleCopy release];
      [reachable release];

      //NSLog( @"Unreachable %d", [unreachable count] );

      // break all the retain cycles!
      for ( ObSCollectible* node in unreachable ) {
        [node releaseChildren];
      }

      // and now this ought to cause these to get ripped out of the universe
      /*
        int i = 0;
        for ( id x in unreachable ) {
        if ( i++ < 10 ) {
        NSLog( @"%@ RC %d", x, [x retainCount] );
        }
        }
      */
      [unreachable release];

      /*
        NSLog( @"remaining: %d", [_collectibles count] );
        i = 0;
        for ( id x in _collectibles ) {
        if ( i++ < 10 ) {
        NSLog( @"remaining %@ RC %d", x, [x retainCount] );
        }
        }
      */
    });
}

@end
