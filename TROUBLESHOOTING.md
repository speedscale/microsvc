# Troubleshooting Guide

This guide helps diagnose and resolve common issues with the Banking Application microservices.

## Common Issues

### Frontend Issues

#### Port 3000 already in use
```bash
# Check what's using port 3000
lsof -i :3000
# Kill the process or use a different port
npm run dev -- -p 3001
```

#### Build errors
```bash
# Clear Next.js cache
rm -rf frontend/.next
npm run build
```

#### API connection errors
- Verify backend services are running
- Check API gateway configuration
- Ensure CORS settings are correct

### Backend Issues

#### Database connection failures
```bash
# Check PostgreSQL status
docker ps | grep postgres
# Restart database
docker-compose restart postgres
```

#### Service startup failures
```bash
# Check service logs
docker-compose logs [service-name]
# Verify environment variables
docker-compose config
```

#### JWT token issues
- Check user-service is running
- Verify JWT secret configuration
- Clear browser cookies/localStorage

### Kubernetes Issues

#### Pod startup failures
```bash
# Check pod status
kubectl get pods -n banking-app
# View pod logs
kubectl logs -n banking-app [pod-name]
# Describe pod for events
kubectl describe pod -n banking-app [pod-name]
```

#### Service not accessible
```bash
# Check service endpoints
kubectl get endpoints -n banking-app
# Verify service configuration
kubectl describe svc -n banking-app [service-name]
```

#### Port forwarding issues
```bash
# Check if port is already in use
lsof -i :3000
# Use different local port
kubectl port-forward -n banking-app svc/frontend 3001:3000
```

### Observability Issues

#### Grafana not loading dashboards
- Check Prometheus data source configuration
- Verify metrics are being collected
- Check Grafana logs: `kubectl logs -n banking-app deployment/grafana`

#### Prometheus targets down
```bash
# Check target status
kubectl port-forward -n banking-app svc/prometheus 9090:9090
# Visit http://localhost:9090/targets
```

#### Jaeger not showing traces
- Verify OpenTelemetry configuration in services
- Check Jaeger collector logs
- Ensure services are sending traces to correct endpoint

## Debug Commands

### Docker Compose
```bash
# View all logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f [service-name]

# Check service health
docker-compose ps

# Restart specific service
docker-compose restart [service-name]
```

### Kubernetes
```bash
# Check all resources
kubectl get all -n banking-app

# View events
kubectl get events -n banking-app --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n banking-app

# Debug pod with interactive shell
kubectl exec -it -n banking-app [pod-name] -- /bin/bash
```

### Database
```bash
# Connect to database
docker exec -it [postgres-container] psql -U postgres -d banking_app

# Check database schemas
\dn

# Check table data
SELECT * FROM user_service.users LIMIT 5;
```

## Performance Issues

### High Memory Usage
- Check JVM heap settings in application.yml
- Monitor with: `kubectl top pods -n banking-app`
- Consider increasing resource limits

### Slow Response Times
- Check database connection pool settings
- Monitor with Grafana dashboards
- Verify network latency between services

### Database Performance
```bash
# Check slow queries
docker exec -it [postgres-container] psql -U postgres -d banking_app -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"
```

## Reset Everything

### Local Development
```bash
# Stop and remove all containers
docker-compose down -v

# Remove all images
docker-compose down --rmi all

# Clean start
docker-compose up -d
```

### Kubernetes
```bash
# Delete all resources
kubectl delete namespace banking-app

# Redeploy everything
kubectl apply -k kubernetes/base/
kubectl apply -k kubernetes/observability/
```

## Speedscale Troubleshooting

### Sidecar not injected
```bash
# Check Speedscale operator status
kubectl get pods -n speedscale-system

# Verify annotations are applied
kubectl describe deployment frontend -n banking-app | grep speedscale
```

### Traffic recording issues
```bash
# Check Speedscale sidecar logs
kubectl logs -n banking-app deployment/frontend -c speedscale-sidecar
```

### Performance impact
The Speedscale sidecars add minimal overhead but monitor resource usage during high-traffic scenarios.

## Getting Help

1. **Check logs first**: Most issues can be diagnosed from service logs
2. **Verify prerequisites**: Ensure all required software is installed and up to date
3. **Check network connectivity**: Verify services can communicate with each other
4. **Review configuration**: Ensure all environment variables and configs are correct
5. **Search issues**: Check if the problem has been reported before

## Proxymock Troubleshooting

### Proxymock not starting
```bash
# Check if proxymock is installed
which proxymock

# Check for port conflicts
make proxymock-list
make proxymock-stop
```

### Recording not capturing traffic
- Verify you're sending requests to the proxy port (e.g., 4181 for user-service)
- Check proxy environment variables: `make proxymock-env`
- Ensure the service is running and accessible

### Mock server not responding
```bash
# Check if mock directory has recordings
ls -la proxymock/

# Verify mock server is running
make proxymock-list

# Check mock server logs in output directory
```

### Debug port conflicts
Each service uses different debug and proxy ports:
- user-service: 8081, debug: 5005, proxy: 4181/7481
- accounts-service: 8082, debug: 5006, proxy: 4182/7482  
- transactions-service: 8083, debug: 5007, proxy: 4183/7483
- api-gateway: 8080, debug: 5008, proxy: 4180/7480
- frontend: 3000, debug: N/A, proxy: 4130/7430