os.loadAPI("planterturtle")

planter = planterturtle.PlanterTurtle:new{turtle=turtle}

running = false
print("Standby...")
for event, _ in os.pullEvent do
  if event == 'redstone' then
    running = true
    planter:start()
    running = false
    print("Standby...")
   end
end