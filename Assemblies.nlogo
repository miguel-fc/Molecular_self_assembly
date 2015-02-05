
;;====================================================================== Assemblies 

breed [Assemblies Assembly]   ;; This should have nearly the same -own list as Particles
                              ;; otherwise the variables will be lost when the breed changes
 
Particles-own
[
  components
  
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

to initAssemblies

   ;; reporting task
   set get-energy Task [

   ]


end


