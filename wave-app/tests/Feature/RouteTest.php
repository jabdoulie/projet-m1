<?php

// tests/Feature/RouteResponseTest.php

use function Pest\Laravel\get;
use App\Models\User;

it('responds with 200 for all routes', function (string $route) {
    $response = get($route);
    $response->assertStatus(200);
})->with('routes');

test('responds with 200 for all auth routes', function ($url) {
    $user = User::query()->first() ?? User::factory()->create();

    $this->actingAs($user);

    $response = $this->get($url);

    $response->assertStatus(200);
})->with('authroutes');