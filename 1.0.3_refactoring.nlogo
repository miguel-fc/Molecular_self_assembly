extensions [array profiler]

;;Obs: Does the size at which stability is checked matter?

;;Possible experiemnt: does adding neutral agents increase or decrease rate of reaction?

;;Weird idea: having agents that can overlap can simulate the formation of molecules in dimensions greater than 3?

;;Should the agent still move, even if it was split?

;;Change colors
;;Run sims- find averages and stuff
;;40 particles

;;hex has up to 2 patches here
;start energy at 0

;;max size- splitting vs merging
;;limit size to 9

;;print graph

;refactor with tasks

;update stability scoreboard with agents that are larger?


globals 
[
  colors           ;; colors we are using
  global-energy    ;; total global-energy of the system
  previous-global-energy ;; total previous-global-energy of the system (before an attempted move)
  min-global-energy
  energy-plot
  start-E
  E0
  maxSize ;;maximum size of each cluster, increases with time
  linSize
  logSize
  ;;initializes an array of 100 values to 100. These values will be the record low energies found by each group such that
  ;; energy[a]=b means the lowest energy of a block of size a was b
  record-low-E
  started-timer
  
  ;;common temp variables
  guy
  counter
  counter2
  counter3
  move-counter
  movement
  dummy-energy
  dummy-energy2
  dummy-follower-energy
  cands
  partial-energy
  followers
  prob
  triple-candidates
  double-candidates
  
  
  ;;monte-carlo-variables
  std-rot
  mc-E
  mc-locs
  mc-P
  mc-cum-P
  move
  M
  
  ;;testing variables
  tests
  fail
  fails
  sucs
  
  ;;printing variables
  final-time
]
breed [nodes node]
breed [walkers walker]
nodes-own []
walkers-own [candidates did-split will-merge location leader probability itrans-accepted 
  follower-energy walker-energy leader-energy prev-leader-energy number-of-parts stationary merge-target
  queen hivers drone-energy queen-energy prev-queen-energy hive-size]


;Set up routine: creates a grid of patches. Puts nodes on each patch, links them and then puts 
;a number of walkers on the nodes. 
to setup
  clear-all
  profiler:start
  
  set-default-shape nodes "square"
  if sim-shape = "square"
  [
   set-default-shape walkers "square"
  ]
  if sim-shape = "hex"
  [
   set-default-shape walkers "circle" 
  ]
  set tests 0
  set fails 0
  set sucs 0
  set fail false
  
  if printable
  [
    let file user-new-file
    if is-string? file
    [
     if file-exists? file
       [file-delete file]
     file-open file
    ]
  ]

  make-sim
  
  reset-ticks
end

to make-sim
  set tests tests + 1
  set fail false
  type "\nTest Number " show tests type "\n"
  ask links [untie die]
  ask turtles [die]
  set min-global-energy 0
  
  set mc-E array:from-list n-values (11) [10000]
  set mc-locs array:from-list n-values (11) [0]
  set mc-P array:from-list n-values (11) [0]
  set mc-cum-P array:from-list n-values (11) [0]
  
  set energy-plot array:from-list n-values (stop-point + 1) [404]
  
  make-nodes
 
 
;;Put "walkers" on the lattice
  set colors [red blue black] ; different colors represent -/+/neutral charges.
  set maxSize 2
  
  make-walkers
  
  ;make-25
  
  set record-low-E array:from-list n-values (number + 1) [505]
  ;;Create scoreboard array
  
  run task find-global-energy
  ask walkers
  [
    compute-E-of-this-leader
    set stationary false
  ]
  
  set started-timer false
  reset-ticks
end

to make-walkers
  if sim-type = "random"
  [
    create-walkers number
    [
      set color item random 3 colors
      move-to one-of nodes with [not any? walkers-all-right-here]
      set leader self
      set queen self
      set hivers self
    ]
  ]
  
  if sim-type = "20 20 10"
  [
    set number 50
    spawn-n-walkers-of-color blue 20
    spawn-n-walkers-of-color black 20
    spawn-n-walkers-of-color red 10
  ]
  if sim-type = "20 lines"
  [
    spawn-shapes 20 (task make-25) 4 -13 4
  ]
  if sim-type = "20 9s"
  [
    spawn-shapes 20 task make-9 4 -13 4
  ]
  if sim-type = "40 lines"
  [
    spawn-shapes 40 task make-25 4 -13 4
  ]
  if sim-type = "40 9s"
  [
    spawn-shapes 40 task make-9 4 -13 4
  ]
  if sim-type = "40 19s"
  [
    spawn-shapes 40 task make-19 4 -13 4
  ]
end

to spawn-shapes [n command numParts indiEner startMaxSize]
  set counter 1
  while [counter <= n]
  [
      run command
      set counter counter + 1
  ]
  set number n * numParts
  set start-E n * indiEner
  set maxSize startMaxSize
end

to make-nodes
  if sim-shape = "square"
  [
    set-default-shape nodes "square"
    ask patches
    [ 
      sprout-nodes 1
      [ 
        set color white ;; white
        set size 1.2
      ] 
    ]
    ;; Connect the nodes to make a lattice
    ask nodes
    [ 
        create-links-with nodes-on patches at-points [[0 1] [1 0] ]    
    ]  
    ask links [ hide-link ]
    
    set std-rot 90
  ]
end

to make-9
  let loc one-of nodes with [not any? walkers-all-right-here]
  make-hive red red black blue
    loc
    one-of [nodes at-points [[-1 0 ] ]] of loc
    one-of [nodes at-points [[-1 -1] ]]  of loc
    one-of [nodes at-points [[-1 -2] ]]  of loc
end

to make-25
  let loc one-of nodes with [not any? walkers-all-right-here]
  make-hive red black blue red 
    loc
    one-of [nodes at-points [[0 -1] ]] of loc
    one-of [nodes at-points [[0 -2] ]]  of loc
    one-of [nodes at-points [[0 -3] ]]  of loc
end

to make-19
  let loc one-of nodes with [not any? walkers-all-right-here]
  make-hive red black blue red 
    loc
    one-of [nodes at-points [[0 -1] ]] of loc
    one-of [nodes at-points [[0 1] ]]  of loc
    one-of [nodes at-points [[1 0] ]]  of loc
end

to make-hive [qclr c1 c2 c3 qloc loc1 loc2 loc3]
  let qun 0
  
  create-walkers 1
  [
    set queen self
    set color qclr
    move-to qloc
    set leader self
    set qun self
  ]
  
  spawn-drone-at loc1 c1 qun
  spawn-drone-at loc2 c2 qun
  spawn-drone-at loc3 c3 qun

  ask qun
  [
    set hivers walkers with [queen = myself]
    ask hivers
    [
     create-links-with other ([hivers] of queen) [tie hide-link]
    ]
    
    let rot random 5
    rt rot * std-rot
  ]
  
  ask qun
  [
   while [queen-overlaps]
   [
     move-to one-of nodes with [not any? walkers-all-right-here]
   ]
  ]
end


to spawn-drone-at [loc clr q]
  create-walkers 1
  [
    set queen q
    set color clr
    move-to loc
    set leader queen
  ]
end


to spawn-n-walkers-of-color [clr n]
  create-walkers n
    [
      set color clr
      move-to one-of nodes with [not any? walkers-all-right-here]
      set leader self
      set queen self
      set hivers self
    ]
end

to write-data
  let file user-new-file
    if is-string? file
    [
      type "Good"
     if file-exists? file
       [file-delete file]
     file-open file
    ]
  
  set counter 0
  
  while [counter <= ticks - 1]
  [
   file-print (word counter " " array:item energy-plot counter)
   set counter counter + 1
  ]
  
  file-close 
end

to write-stats
  set final-time timer
  
  file-print (word "\nTime elapsed: " final-time " seconds")
  file-print (word "Ticks: " ticks)
  file-print (word (ticks / final-time) " Ticks per second\n" )
  file-print (word "Min energy: " min-global-energy "")
  file-print (word "Simulation type: " sim-type "")
  file-print (word "Growth Rate: " growthRate "")
  file-print (word "Beta: " beta "")
  file-print (word "Splitting power: " splitting-power "\n\n")
  
  file-close
end

;Main loop.
to go
  if started-timer = false
  [
   set started-timer true
   reset-timer 
  ]
  ;type "\n\nTick " show ticks
  if not infinite and ticks >= stop-point
    [
      if printable
      [
        file-print (profiler:report)
        file-print (word "\n\n\n\n\n")
        write-stats
      ]
      
      ifelse fail
      [type "Failure"
        set fails fails + 1]
      [type "Success!"
        set sucs sucs + 1]
      
      ifelse tests < max-tests
      [make-sim]
      [
        if printable
        [write-data]
        type "\nFails: " show fails type "\n Successes: " show sucs
        profiler:stop
        stop
      ]
    ]
  
  check-error
  if stop-on-failure
  [
    if fail
    [
      type "Failure- stopping program"
      stop
    ]
  ]
  
  inc-max-size
  set beta beta + heatingRate
  
  set guy one-of walkers with [leader = self]
  ;show guy
  ask guy
  [
    ifelse should-split and agent-based and splitting
    [
      ;type "Do the splitty-splitty thing\n"
      split 
      ;check-error
    ]
    [
      ;type "Do the walky-walky thing\n"
      one-move
      ;check-error
  
      if stationary and agent-based
      [  
        ;type "Do the mergy-mergy thing\n"
        merge 0
        ;check-error
      ]
    ]
  ]
  
  ;type "Find the global energy\n"
  run task find-global-energy
  if printable
  [
   array:set energy-plot ticks global-energy 
  ]
  ;check-error
  tick
end

to inc-max-size
  if maxSize < maxSizeLimit
   [set maxSize maxSize + growthRate]
end

to check-error
  nodes-check-if-full
  
  if stop-on-failure
  [
    if fail
    [
      type "Failure- stopping program"
      stop
    ]
  ]
end

to check-bad-mc-calc
  if sim-shape = "square"
  [
    if (array:item mc-E 3 != 10000 or array:item mc-E 4 != 10000 or
        array:item mc-E 9 != 10000 or array:item mc-E 10 != 10000 or
         array:item mc-P 3 != 0 or array:item mc-P 3 != 0 or
         array:item mc-P 9 != 0 or array:item mc-P 10 != 0 )
    [set fail true]
  ]
end

to clean-up [grp]
  ask grp
  [
    ask nodes
    [
      if (distance myself < .3) and (distance myself > .01)
      [
        ask myself
        [
          ask my-links [untie]
          move-to myself
          ask my-links [tie]
        ]
      ]
    ]
  ]
end

to-report leader-is-hiver
  let answer false
  ask hivers
  [
    if leader = self
    [set answer true]
  ]
  report answer
end

;target should be a leader
to-report should-merge-with [target]
  ifelse stationary and 
   (number-of-parts + [number-of-parts] of target <= maxSize)
  [report true]
  [report false]
end

to-report should-split
  ifelse number-of-parts > 1 and
       ( 
         (less-than-most-stable leader-energy number-of-parts) 
         or 
         (number-of-parts > maxSize and size-limit-type = "split") 
       )
  [report true]
  [report false]
end

to split
  
  ask max-one-of walkers with [queen = self and leader = [leader] of myself] [[queen-energy] of queen]
  [
    let splitter self
    let old-leader leader
    set leader self
    ask hivers
    [
      destroy-all-my-links
      set leader queen
    ]
    
    ifelse move-split
    [
      set counter2 0
      set beta beta * splitting-power
      while [counter2 < 1000]
      [
        ask [queen] of splitter
        [
          one-move
          
          if stationary and merge-in-split
          [
            set stationary false
            set counter2 1000
          ]
        ]
        set counter2 counter2 + 1
      ]
      set beta beta / splitting-power
    ]
    [
      let new-loc one-of nodes with [not any? walkers-all-right-here] 
      move-to new-loc
  
      while [queen-overlaps]
      [
       move-to one-of nodes with [not any? walkers-all-right-here]
      ]
    ]
 
    let leftovers walkers with [leader = old-leader and queen != splitter]
    ask leftovers
    [
      set leader queen
      destroy-all-my-links
    ]
    ask leftovers
    [
      merge leftovers
    ]
    
    run task find-global-energy
    compute-E-of-this-leader
  ]
end

;;Reports whether or not a cluster with num-parts parts and ener leader-energy will be as stable or more stable as all of the previous clusters
;;of smaller size
to-report less-than-most-stable [ener num-parts]
  set counter3 2
  let less-stable false
  let uno (ener / num-parts)
  while [counter3 <= num-parts]
  [
    if (array:item record-low-E counter3 / counter3) < uno
    [
      set less-stable true
    ]
    set counter3 counter3 + 1
  ]
  
  report less-stable
end

;;Tells the walker calling it to make one move, choosing a move to make based on the energies that it would have at all possible moves,
;;then making that move
to one-move
  ;Initializing values 
        set followers walkers with [leader = [leader] of myself]
        ;run task find-global-energy
        find-partial-energy followers
        ;set previous-global-energy global-energy
        set E0 partial-energy
        set movement -1
        ;Initialize the number of translational steps accepted
        ;If this variable is 0, the movement was accepted, if it's one, the movement was not accepted
        set itrans-accepted 0
        set will-merge false
        let origin node-right-here
        let mi self
        set move-counter 0
        
        ifelse (queen = self and leader = self and number-of-parts = 1)
        [

           array:set mc-E 0 10000
           array:set mc-E 1 10000
           array:set mc-E 2 10000
           array:set mc-E 3 10000
           array:set mc-E 4 10000
        ] 
        [
          rt std-rot
          compute-energy-of-this-movement followers
          while [ (move-counter + 1) < (360 / std-rot) ]
          [
            array:set mc-E move-counter partial-energy
            rt std-rot
            compute-energy-of-this-movement followers
            set move-counter move-counter + 1
          ]
        ]
        ;type "checking moves"
        set move-counter 5
        ask [link-neighbors] of (node-right-here)
        [
          ask mi
          [
            move-to myself
            compute-energy-of-this-movement followers
            array:set mc-E move-counter partial-energy
            array:set mc-locs move-counter myself
          ]
          set move-counter move-counter + 1
        ]
        move-to origin
          
        
        ;print mc-E 
                
        ;;find M, the number of applicable moves
        set M 0
        set move-counter 0
        while [move-counter <= array:length mc-E - 1]
        [
          if array:item mc-E move-counter < 9000
          [
            set M M + 1
          ]
          set move-counter move-counter + 1
        ]
        
        ;type "M: " print M
        
        ;;find the probabilities of each move
        set move-counter 0
        while [move-counter <= array:length mc-E - 1]
        [
          ifelse array:item mc-E move-counter > 9000
          [
            array:set mc-P move-counter 0
            ;type "Detecting high global energy\n"
          ]
          [
            set prob 0
            let deltaEbeta (E0 - array:item mc-E move-counter) / beta 
            set prob (min list 1 exp (deltaEbeta)) / M
            array:set mc-P move-counter prob
            ;type "Detecting normal global energy\n"
          ]
          set move-counter move-counter + 1
        ]
        
        ;print mc-P
        
        ;;Find the cumulative probability distribution. This will be used to choose an action.
        array:set mc-cum-P 0 (array:item mc-P 0)
        set move-counter 0
        while [move-counter <= array:length mc-P - 2]
        [
          array:set mc-cum-P (move-counter + 1) array:item mc-cum-P move-counter + array:item mc-P (move-counter + 1)
          set move-counter move-counter + 1
        ]
        
        ;print mc-cum-P
        
        ;;choose movement
        set prob random-float 1
        let chosen false
        set move-counter 0
        while [move-counter <= array:length mc-cum-P - 1]     
        [
          if (not chosen) and (prob < array:item mc-cum-P move-counter)
          [
            set movement move-counter
            set chosen true
          ]
          set move-counter move-counter + 1
        ]
        
        ;type "Movement: " show movement

        
        ifelse movement < 0
        [
          set will-merge true
          set stationary true
        ][
        ifelse movement <= 4
        [
          rt std-rot * (movement + 1)
          ;clean-up link-neighbors
        ][
          move-to array:item mc-locs movement
        ]     
        ]
        run task find-global-energy
        
        if sim-shape = "hex"
        [clean-up link-neighbors]
        
;check-error
;check-bad-mc-calc
;  if stop-on-failure
;  [
;    if fail
;    [
;      type "Failure- stopping program"
;      stop
;    ]
;  ]
        
end


to nodes-check-if-full
  ask nodes 
  [
    ifelse count walkers-all-right-here > 1
    [set color violet type "UHOH" set fail true]
    [
      if sim-shape = "square"
      [set color white]
      if sim-shape = "hex"
      [set color grey - 3]
    ]
  ]
end
 
to find-partial-energy [grp]
  set partial-energy 0
  ask grp
  [
    find-my-energy
    set partial-energy partial-energy + walker-energy
  ]
end

;Finds the total global-energy (Note the /2 is to avoid double counting).
to find-global-energy

  set global-energy  -1 * start-E
  ask walkers 
  [
    find-my-energy
    set global-energy global-energy + walker-energy
  ]
  
  find-queens-energy
   
   if global-energy < min-global-energy
     [set min-global-energy global-energy]
     
end

to find-my-energy
  set walker-energy 0
  set follower-energy 0
  set cands walkers-on neighbors4
    
  ;;positive
  ifelse [color] of self  = blue 
  [
    total-energies-of-colors cands red -.5 blue 4.5 black -5.5 
  ][                       
  ;;neutral 
  ifelse [color] of self  = red 
  [ 
      total-energies-of-colors cands red -.5 blue -.5 black -.5
  ][    
    ;;negtive
  if [color] of self  = black 
  [
      total-energies-of-colors cands red -.5 blue -5.5 black 4.5 
  ] 
  ]]
end

to find-queens-energy
  ask walkers with [queen = self]
  [
    set dummy-energy 0
    if is-agentset? hivers
    [
     ask other hivers
     [
       set dummy-energy dummy-energy + follower-energy
     ]    
    ]
    set queen-energy follower-energy + dummy-energy
  ]
end

to find-cands [grp]
  set triple-candidates [(walkers-on neighbors4) with [leader != [leader] of myself]] of walkers with [leader = myself]
  set double-candidates turtle-set triple-candidates
  set candidates double-candidates
  
  if is-agentset? grp
  [
   set candidates double-candidates with [member? self grp]
  ]
end

to merge [grp]
  
  find-cands grp
  
  if any? candidates 
  [
    let chosen-one one-of candidates
    let new-leader [leader] of chosen-one
    if number-of-parts + [number-of-parts] of new-leader <= maxSize
    [
      ask walkers with [leader = myself]
      [
        set leader new-leader
        if queen = self
        [
          destroy-all-my-links
          create-link-with new-leader [tie]
        ]
      ]
    ]
  
    ask leader
    [
      run task find-global-energy
      compute-E-of-this-leader
    ]
  ]
end


;;Tells the links of a walker to die, but preseves its links to its queen and fellow drones
to destroy-all-my-links
  ask walkers with [queen = [queen] of myself]
  [
   ask my-links [untie die]
  ]
  
  ask queen
  [
   create-links-with other walkers with [queen = [queen] of myself] [tie hide-link]
  ]
  
end

;;Checks whether a queen or any of her drones is overlapping another agent.
to-report queen-overlaps
  let overlaps false
  
    if is-agentset? [hivers] of queen
    [
      ask [hivers] of queen
      [
        if any? other walkers-all-right-here; with [leader != [leader] of myself] 
        [set overlaps true]  
      ]               
    ]
  
  report overlaps
end

; Evaluates the energy of a potential movement. 
to compute-energy-of-this-movement [grp]
  let ifind 0
  
  ask walkers with [leader = [leader] of myself]
  [
    if ifind = 0 and any? other walkers-all-right-here
    [set ifind 1]
  ]
  
  ifelse ifind = 0 
    [find-partial-energy grp];
    [set partial-energy 10000]
end

;Compute the energy of each agentset (a cluster of walkers) and keeping track of it
;;Currently only updates the score of same size
to compute-E-of-this-leader 
    set prev-leader-energy leader-energy

    set dummy-energy 0
    ask other walkers with [leader = [leader] of myself] 
    [
      set dummy-energy dummy-energy + follower-energy
    ]    
    set leader-energy dummy-energy + follower-energy
    
    set number-of-parts count walkers with [leader = myself]
    
    ;;update scoreboard
    if prev-leader-energy != leader-energy
    [
      ;set counter number-of-parts
      ;while [counter < number]
      ;[
        if array:item record-low-E number-of-parts > leader-energy
        [
          array:set record-low-E number-of-parts leader-energy
        ]
        ;set counter counter + 1
      ;]
    ]
end

to total-energies-of-colors [group c1 v1 c2 v2 c3 v3]
  
  set dummy-energy2 0
  set dummy-follower-energy 0
  ask group
  [
    ifelse color = c1
    [
      set dummy-energy2 dummy-energy2 + v1
      if leader = [leader] of myself
      [
        set dummy-follower-energy dummy-follower-energy + v1
      ]
    ][
    ifelse color = c2
    [
      set dummy-energy2 dummy-energy2 + v2
      if leader = [leader] of myself
      [
        set dummy-follower-energy dummy-follower-energy + v2
      ]
    ][
    if color = c3
    [
      set dummy-energy2 dummy-energy2 + v3
      if leader = [leader] of myself
      [
        set dummy-follower-energy dummy-follower-energy + v3
      ]
    ]
    ]]
  ]
  set walker-energy dummy-energy2
  set follower-energy dummy-follower-energy
end


;;is a walker method, not a node method
to-report walkers-on-neighbors6
  report walkers-on [link-neighbors] of node-right-here
end

to-report node-right-here
  ifelse sim-shape = "square"
  [report one-of nodes-here]
  [
  let mi self
  report one-of nodes with [distance mi < .01]
  ]
end

to-report walker-right-here
  let rep 0
  ifelse sim-shape = "square"
  [set rep one-of walkers-here]
  [
  set rep one-of walkers with [distance myself < .01]
  ]
  report rep
end

to-report walkers-all-right-here
  ifelse sim-shape = "square"
  [report walkers-here]
  [
  report walkers with [distance myself < .01]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
208
11
646
470
16
16
12.97
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

SLIDER
665
57
837
90
number
number
0
100
160
1
1
NIL
HORIZONTAL

PLOT
24
534
1384
1025
Energy
ticks
Energy
0.0
2000.0
-600.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot global-energy"

BUTTON
655
14
721
47
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
724
15
788
48
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
791
14
854
47
step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
10
169
67
214
Min 2
array:item record-low-E 2
1
1
11

MONITOR
71
168
128
213
Min 3
array:item record-low-E 3
17
1
11

MONITOR
132
168
189
213
Min 4
array:item record-low-E 4
17
1
11

MONITOR
11
216
68
261
Min 5
array:item record-low-E 5
17
1
11

MONITOR
70
216
127
261
Min 6
array:item record-low-E 6
17
1
11

MONITOR
133
214
190
259
Min 7
array:item record-low-E 7
17
1
11

MONITOR
12
264
69
309
Min 8
array:item record-low-E 8
17
1
11

MONITOR
73
264
130
309
Min 9
array:item record-low-E 9
17
1
11

MONITOR
133
264
190
309
Min 10
array:item record-low-E 10
17
1
11

MONITOR
834
364
898
409
NIL
maxSize
1
1
11

SWITCH
655
97
763
130
splitting
splitting
0
1
-1000

CHOOSER
680
195
818
240
sim-type
sim-type
"random" "20 20 10" "20 lines" "20 9s" "40 lines" "40 19s" "40 9s"
4

MONITOR
9
423
66
468
reds
count walkers with [color = red]
17
1
11

MONITOR
69
425
126
470
blues
count walkers with [color = blue]
17
1
11

MONITOR
129
422
186
467
blacks
count walkers with [color = black]
17
1
11

SWITCH
659
250
762
283
infinite
infinite
1
1
-1000

INPUTBOX
674
296
829
356
stop-point
50000
1
0
Number

INPUTBOX
675
358
830
418
growthRate
0.0050
1
0
Number

MONITOR
51
472
132
517
Min Energy
min-global-energy
1
1
11

INPUTBOX
672
133
827
193
max-tests
10
1
0
Number

MONITOR
771
90
828
135
tests
tests
17
1
11

SWITCH
308
478
462
511
stop-on-failure
stop-on-failure
0
1
-1000

MONITOR
1030
18
1087
63
MIN2
array:item record-low-E 2 / 2
17
1
11

MONITOR
1089
18
1146
63
MIN3
array:item record-low-E  3 / 3
17
1
11

MONITOR
1030
64
1087
109
MIN5
array:item record-low-E 5 / 5
17
1
11

MONITOR
1090
67
1147
112
MIN6
array:item record-low-E 6 / 6
17
1
11

MONITOR
1151
69
1208
114
MIN7
array:item record-low-E 7 / 7
17
1
11

MONITOR
1031
116
1088
161
MIN8
array:item record-low-E 8 / 8
17
1
11

MONITOR
1092
114
1149
159
MIN9
array:item record-low-E 9 / 9
17
1
11

MONITOR
1153
118
1210
163
MIN10
array:item record-low-E 10 / 10
17
1
11

INPUTBOX
675
419
830
479
beta
0.5
1
0
Number

SWITCH
481
478
616
511
agent-based
agent-based
0
1
-1000

SWITCH
841
181
953
214
printable
printable
1
1
-1000

MONITOR
11
311
68
356
Min 12
array:item record-low-E 12
17
1
11

MONITOR
73
310
130
355
Min 16
array:item record-low-E 16
17
1
11

MONITOR
133
311
190
356
Min 20
array:item record-low-E 20
17
1
11

MONITOR
10
358
67
403
Min 28
array:item record-low-E 28
17
1
11

MONITOR
71
360
128
405
Min 36
array:item record-low-E 36
17
1
11

MONITOR
132
359
189
404
Min 48
array:item record-low-E 48
17
1
11

SWITCH
848
54
972
87
move-split
move-split
0
1
-1000

SWITCH
848
91
996
124
merge-in-split
merge-in-split
0
1
-1000

INPUTBOX
679
492
834
552
heatingRate
0
1
0
Number

CHOOSER
845
129
983
174
sim-shape
sim-shape
"square" "hex"
0

BUTTON
1128
306
1285
339
Resize for hexagons
resize-world -15 16 -15 16
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1130
352
1276
385
Resize for Original
resize-world -16 16 -16 16
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
901
361
1056
421
maxSizeLimit
36
1
0
Number

CHOOSER
835
219
973
264
size-limit-type
size-limit-type
"merge" "split"
0

MONITOR
867
291
924
336
Time
timer
1
1
11

INPUTBOX
856
427
1011
487
splitting-power
20
1
0
Number

@#$#@#$#@
## WHAT IS IT?

See the paper: "An agent-based approach for modeling molecular self-organization" Troisi et al., PNAS, 102, 255-260 (2005) This code is based on one taken from the Netlogo repository but improved in several ways so as to reproduce the results in the paper reference above 

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
