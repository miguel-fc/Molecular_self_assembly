
;;====================================================================== Components 

breed [Components Component]   ;; This should have nearly the same -own list as Particles
                               ;; otherwise the variables will be lost when the breed changes
 
Particles-own
[candidates         ;; describe each of these
 did-split
 will-merge
 merge-target
 location
 leader
 probability
 itrans-accepted 
 follower-energy
 walker-energy
 leader-energy
 prev-leader-energy
 number-of-parts
 stationary
 queen
 hivers
 drone-energy
 queen-energy
 prev-queen-energy
 hive-size

 ;;---------------------------------------- task variables
 get-energy
 
]

;;====================================================================== Particle proceedures

to initComponents

   ;; reporting task
   set get-energy Task [

   ]


end


