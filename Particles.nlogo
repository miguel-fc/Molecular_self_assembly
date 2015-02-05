
;;====================================================================== Particles 

breed [Particles Particle]

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

 get-neighbors
 getEnergyBetweenSelfAnd
 get-energy
]

;;====================================================================== Particle proceedures

;----------------------------------------------------------------------

to-report getEnergyBetweenBlueSelfAnd [otherParticle]

   if otherParticle.color = red   [ report  -.5 ]
   if otherParticle.color = blue  [ report  4.5 ]
   if otherParticle.color = black [ report -5.5 ]
   report 0
end
 
;----------------------------------------------------------------------

to-report getEnergyBetweenRedSelfAnd [otherParticle]

   if otherParticle.color = red   [ report  -.5 ]
   if otherParticle.color = blue  [ report  -.5 ]
   if otherParticle.color = black [ report  -.5 ]
   report 0
end
 
;----------------------------------------------------------------------

to-report getEnergyBetweenBlackSelfAnd [otherParticle]

   if otherParticle.color = red   [ report  -.5 ]
   if otherParticle.color = blue  [ report -5.5 ]
   if otherParticle.color = black [ report  4.5 ]
   report 0
end
 
;;----------------------------------------------------------------------

to setColor [acolor]

   set color acolor
   
   if [acolor] = blue
    [ set getEnergyBetweenSelfAnd Task [ getEnergyBetweenBlueSelfAnd ]]

   if [acolor] = red
    [ set getEnergyBetweenSelfAnd Task [ getEnergyBetweenRedSelfAnd ]]

   if [acolor] = black	
    [ set getEnergyBetweenSelfAnd Task [ getEnergyBetweenBlackSelfAnd ]]
    
end

;----------------------------------------------------------------------

to initParticle

   set get-neighbors Task [ report Particles-on neighbors4 ]

   set get-energy Task [

      let energyToSum Task [
       	   if is-Particle ?1
	      [ report getEnergyBetweenSelfAnd ?1 + getEnergyBetweenSelfAnd ?2 ]
	   report ?1 + getEnergyBetweenSelfAnd ?2 ]
       ]
       
       report reduce energyToSum run get-neighbors
   ]
end

;;----------------------------------------------------------------------
