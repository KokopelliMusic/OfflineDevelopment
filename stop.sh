containers=("mockify" "tawa" "spotify_auth" "redis")

echo ""
echo "    Shutting down the kokopelli development environment"
echo "        Note: this does not shutdown the frontend development servers"
echo ""

echo "Stopping supabase"
supabase stop

for container in ${containers[@]}; do
  echo "Stopping" $container
  docker stop "kokopelli_"$container
done