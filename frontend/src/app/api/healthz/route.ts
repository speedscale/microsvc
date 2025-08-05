export async function GET() {
  return Response.json(
    { 
      status: 'UP',
      timestamp: new Date().toISOString(),
      service: 'frontend'
    },
    { status: 200 }
  );
}