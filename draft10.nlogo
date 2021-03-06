extensions [array]

;;Observation: if there are enough agents on screen, then clusters will build faster than they can split though the limitation
;;of their size. This could simulate a system in which molecules and clusters form not with perfect stability, but with speed?

;;Possible experiemnt: does adding neutral agents increase or decrease rate of reaction?

;;Weird idea: having agents that can overlap can simulate the formation of molecules in dimensions greater than 3?

globals 
[
  colors           ;; colors we are using
  global-energy    ;; total global-energy of the system
  previous-global-energy ;; total previous-global-energy of the system (before an attempted move)
  min-global-energy
  maxSize ;;maximum size of each cluster, increases with time
  linSize
  logSize
  ;;initializes an array of 100 values to 100. These values will be the record low energies found by each group such that
  ;; energy[a]=b means the lowest energy of a block of size a was b
  record-low-E
]
breed [nodes node]
breed [walkers walker]
nodes-own [full]
walkers-own [location leader probability  itrans-accepted walker-energy leader-energy prev-leader-energy number-of-parts]


;Set up routine: creates a grid of patches. Puts nodes on each patch, links them and then puts 
;a number of walkers on the nodes. 
to setup
  clear-all
  set-default-shape nodes "square"
  ask patches
  [ 
    sprout-nodes 1
    [ 
      set color white ;; white
      set size 1.2
      set full 0
    ] 
  ]
  ;; Connect the nodes to make a lattice
  ask nodes
  [ 
      create-links-with nodes-on patches at-points [[0 1] [1 0] ]    
  ]  
  ask links [ hide-link ]
 
 
;;Put "walkers" on the lattice
  set-default-shape walkers "square"
  set colors [red blue black] ; different colors represent -/+/neutral charges.
  make-walkers
  
  set record-low-E array:from-list n-values (number + 1) [100]
  ;;Create scoreboard array
  
  set linSize 2
  
  reset-ticks
end

to make-walkers
  if sim-type = "random"
  [
    create-walkers number
    [
      set color item random 3 colors
      set location one-of nodes with [full = 0]
      ask location [set full 1]
      set leader self
      move-to location
    ]
  ]
  
  if sim-type = "20 20 10"
  [
    set number 50
    spawn-n-walkers-of-color blue 20
    spawn-n-walkers-of-color red 20
    spawn-n-walkers-of-color black 10
  ]
end

to spawn-n-walkers-of-color [clr n]
  create-walkers n
    [
      set color clr
      set location one-of nodes with [full = 0]
      ask location [set full 1]
      set leader self
      move-to location
    ]
end

;Main loop.
to go
  ;;type "Tick " show ticks
  
  if not infinite and ticks >= stop-point
    [stop]
  
  if splitting
    [
      inc-max-size
      split-all
      if exhaustiveSplitting
      [
        while [any? walkers with [leader = self and number-of-parts > maxSize] ]
          [
            split-all
          ]
      ]
    ]
  
  reorganize
  
  choose_direction
  

  find-global-energy
  ;;type " global energy " ;;show global-energy

  show-all-stats

  nodes-check-if-full
  
  tick
end

to inc-max-size
  set linSize linSize + growthRate
  set logSize ln linSize
  ifelse size-growth-type = "linear"
  [
   set maxSize linSize
  ]
  [
    set maxSize ln linSize
  ]
end

to split
  set leader self 
  ;;set color green
  destroy-all-my-links
  let new-loc one-of nodes with [full = 0] 
  set-location new-loc
end

to split-all
;;************
    ask walkers with 
    [
       leader = self and number-of-parts > 1 and
       ( (array:item record-low-E number-of-parts < leader-energy) or (number-of-parts > maxSize) )
       ;;will split
    ] 
    [ 

       let leaderon who
       ask max-one-of walkers with [the-same-leader] [walker-energy] 
       [
         ;;accounts for the splitt-ee being the leader
         if who = leaderon
         [
           ;;let new-leader one-of other walkers with [the-same-leader]
           ask other walkers with [the-same-leader]
           [
             set leader self
           ]
         ]
         ;;***********
          split
          find-global-energy
        ]
      
    ]         
      
    ;;re-evaluate leaders and existance and such
    reorganize
    find-global-energy

end

;Takes test steps in each of the four directions.
to choose_direction
  
  ask walkers with [leader = self] 
  [         
        ;Initializing values 
        set probability 0      
        find-global-energy
        set previous-global-energy global-energy
        ;Initialize the number of translational steps accepted
        ;If this variable is 0, the movement was accepted, if it's one, the movement was not accepted
        set itrans-accepted 0
        
        ;Choose a movement from a random distribution between 0 and 4
        let movement random 5
        ;0 = stay put
        ;1 = down
        ;2 = up
        ;3 = right
        ;4 = left

        ;stay in the same place, but do a rotation if it lowers the energy
        if movement = 0 
        [
          try-to-rotate
        ]
  

        ;down
        if movement = 1 
        [
          set-location one-of [link-neighbors at-points [[0 -1] ]]  of location
          monte-carlo
          if itrans-accepted = 1 
          [
            set-location one-of [link-neighbors at-points [[0 1] ] ] of location
            compute-energy-of-this-movement
          ]
        ]

        ;up
        if movement = 2 [
          set-location one-of [link-neighbors at-points [[0 1] ] ] of location
          monte-carlo
          if itrans-accepted = 1 [set-location one-of [link-neighbors at-points [[0 -1] ] ] of location
            compute-energy-of-this-movement]
        ]          

        ;right
        if movement = 3 [
          set-location one-of [link-neighbors at-points [[1 0] ] ] of location
          monte-carlo
          if itrans-accepted = 1 [set-location one-of [link-neighbors at-points [[-1 0] ] ] of location
            compute-energy-of-this-movement]
        ]
        
        ;left
        if movement = 4 [
          set-location one-of [link-neighbors at-points [[-1 0] ] ] of location
          monte-carlo
          if itrans-accepted = 1 [set-location one-of [link-neighbors at-points [[1 0] ] ] of location
            compute-energy-of-this-movement]
        ]  
        
                         
      ]
     
end

to nodes-check-if-full
  ask nodes 
  [
    ifelse any? walkers-here 
    [set full 1]
    [set full 0]
    
    ifelse count walkers-here > 1
    [set color violet type "UHOH"]
    [set color white]
  ]
end
 

;Finds the total global-energy (Note the /2 is to avoid double counting).
to find-global-energy
  set global-energy  0
  ask walkers 
  [
    set walker-energy 0
    if [color] of self  = blue [total-energy-for -5.5 4.5 -.5]                        
    if [color] of self  = red [total-energy-for 4.5 -5.5 -.5]    
    if [color] of self  = black [total-energy-for -.5 -.5 -.5  ] 
    set global-energy global-energy + walker-energy
  ]
   
   if global-energy < min-global-energy
     [set min-global-energy global-energy]
end

to reorganize
  merge-all
  link-all
end

; Merges agents when they are next to each other.
to merge 
      set leader [leader] of myself
      ask link-neighbors with [not the-same-leader] 
      [ merge ]
end

to merge-all
  ask walkers 
  [
  let candidates (walkers-on neighbors4) with [not the-same-leader]  
  
  if any? candidates
  [ 
    create-links-with candidates [tie]
    ask candidates [merge]
   ] 
  ]
end

; Links each leader to its parts
to link-up
  ask walkers with [the-same-leader] 
    [destroy-all-my-links]
  let otherneighbors other walkers with [the-same-leader]
  create-links-with otherneighbors [tie ;hide-link]
  ]
  
  set number-of-parts 1 + count otherneighbors 
end  

to link-all
  ask walkers with [leader = self] 
 [
  link-up 
  set leader-energy 0
  compute_energy_of_this_leader
 ]
end

to destroy-all-my-links
  ask my-links [untie die]
end

; Required to move agents on the grid
to set-location [new-location]  
  if ([full] of new-location = 0)
  [
  ask location [set full 0]
  set location new-location
  move-to new-location
  ask location [set full 1]
  ]
end


; Evaluates the energy of a translational movement
to compute-energy-of-this-movement
  let ifind 0
  ifelse any? other walkers-here with [not the-same-leader] 
  [set ifind 1]
  [
    if any? link-neighbors with [the-same-leader] ;;why links AND leader?
    [
      ask link-neighbors with [the-same-leader] 
      [
        if any? other walkers-here with [not the-same-leader] 
        [set ifind 1]  
      ]               
    ]
  ]
  ifelse ifind = 0 
    [find-global-energy];
    [set global-energy 1000]
end

; Rotates each leader and its part accordingly
to rotate
  let ifindrot 0
  let rot1 random 4
  rt rot1 * 90  
  if any? link-neighbors with [the-same-leader] 
  [
    ask link-neighbors with [the-same-leader] 
    [
      if any? other walkers-here with [not the-same-leader] 
      [set ifindrot 1]                
    ]
  ]
  if ifindrot = 1 [rt -1 * rot1 * 90]
end


to compute-probability-of-this-movement
  let beta 1
  let deltaEbeta (previous-global-energy - global-energy) * beta 
  set probability (min list 1 exp (deltaEbeta))
end

to monte-carlo
  compute-energy-of-this-movement       
  ifelse global-energy <= previous-global-energy 
  [            
    try-to-rotate
  ]
              
  [ 
    compute-probability-of-this-movement         
    ifelse random-float 1 < probability 
    [  
      try-to-rotate
    ] 
    [ set itrans-accepted 1 ]
  ]
end  

to try-to-rotate
  set previous-global-energy global-energy
  let rot random 4 
  rt rot * 90 
  compute-energy-of-this-movement
  ifelse global-energy <= previous-global-energy
  [ 
    set previous-global-energy global-energy 
  ]
  [
    compute-probability-of-this-movement
    ifelse random-float 1 < probability 
    [ set previous-global-energy global-energy ] 
    [ 
      rt -1 * rot * 90 
      compute-energy-of-this-movement
    ]
  ]
end

;Basic plotting.
to update-plot
  set-current-plot "Energy"
  plot global-energy
end

;Compute the energy of each agentset (a cluster of walkers) and keeping track of it
to compute_energy_of_this_leader 
  set prev-leader-energy leader-energy

  let dummy-energy 0
    ask other walkers with [the-same-leader] 
    [
      set dummy-energy dummy-energy + walker-energy
    ]    
    set leader-energy dummy-energy + walker-energy
    
    ;;update scoreboard
    if prev-leader-energy != leader-energy
    [
      let counter number-of-parts
      while [counter < number]
      [
        if array:item record-low-E counter > leader-energy
        [
          array:set record-low-E counter leader-energy
        ]
        set counter counter + 1
      ]
    ]
end

to-report total-energy-of-color [clr val group]
  let n-of-same-color count group with [color = clr] 
  let counter 0
  let total 0
  while [ counter < n-of-same-color ] 
  [ 
    set counter counter + 1
    set total total + val
  ]
  report total
end

to total-energy-for [rd blu blk]
  let cands walkers-on neighbors4 
         
  set walker-energy walker-energy + 
     total-energy-of-color black (blk) cands +
     total-energy-of-color blue (blu) cands +
     total-energy-of-color red (rd) cands
end


to show-all-stats
  ;;show " Energy of each walker"
  ask walkers 
  [
    ;;show walker-energy
  ]

  ;;show " Energy of each leader "
  ask walkers with [leader = self] 
  [
    ;;show leader-energy 
  ]

  ;;show " # of parts of each leader"
  ask walkers with [leader = self]  
  [
    ;;show number-of-parts
    let unique-parts number-of-parts
  ]

  ;;show "links of each walker"
  ask walkers  
  [
    ;;show count my-links
  ]
end

to-report the-same-leader
  report leader = [leader] of myself
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
649
470
16
16
13.0
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
50
1
1
NIL
HORIZONTAL

PLOT
4
10
204
160
Energy
ticks
Energy
0.0
2000.0
-1300.0
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

CHOOSER
675
139
817
184
exhaustiveSplitting
exhaustiveSplitting
true false
1

CHOOSER
684
431
822
476
size-growth-type
size-growth-type
"linear" "log"
0

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
78
364
142
409
NIL
maxSize
1
1
11

SWITCH
689
94
797
127
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
"random" "20 20 10"
1

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
682
256
785
289
infinite
infinite
0
1
-1000

INPUTBOX
674
296
829
356
stop-point
2000
1
0
Number

INPUTBOX
675
358
830
418
growthRate
0.02
1
0
Number

MONITOR
67
314
148
359
Min Energy
min-global-energy
1
1
11

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
