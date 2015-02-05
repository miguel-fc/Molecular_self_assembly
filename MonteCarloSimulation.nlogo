
;;====================================================================== MonteCarloSimulations 

breed [MonteCarloSimulations MonteCarloSimulation]

MonteCarloSimulations-own
[
  numberOfParticles
  stop-point

  global-energy
  min-global-energy
  energy-plot
  record-low-E

  E
  locs
  P
  cum-P

  ;;------------------------ task variables
  
  get-energy

  deconstruct
]

;;====================================================================== Particle proceedures

to initMonteCarloSimulation [startEnergy ,numParticles,stopPoint]

   set start-energy      startEnergy
   set numberOfParticles numParticles
   set stop-point        stopPoint

   set global-energy     -1 * start-energy   
   set min-global-energy 0
   
   set energy-plot  array:from-list n-values (stop-point        + 1) [404]
   set record-low-E array:from-list n-values (numberOfParticles + 1) [505]	
   
   set E       array:from-list n-values (11) [10000]   ;; where does the 11 come from?
   set locs    array:from-list n-values (11) [0]
   set P       array:from-list n-values (11) [0]
   set cum-P   array:from-list n-values (11) [0]

   ;---------------------------------------- reporter task

   set get-energy Task [

       let energySum Task [
       	   if is-Particle ?1
	      [ report ask ?1 runresult get-energy + ask ?2 runresult get-energy ]
	   report ?1 + ask ?2 runresult get-energy ]
       ]
       let particle-sum reduce energySum Particles
       let assembly-sum reduce energySum Allemblies
       report -1 * start-energy + particle-sum + Particles
  ]       

  ;----------------------------------------

   set deconstruct Task [
   
       ask links    [untie  die]
       ask Paticles [die]

       set started-timer false
       reset-ticks
       die
   ]
   ;----------------------------------------	
end

;;----------------------------------------------------------------------


