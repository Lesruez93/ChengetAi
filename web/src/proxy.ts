import { NextRequest, NextResponse } from "next/server";

import { ADMIN_SESSION_COOKIE, expectedSessionToken } from "@/lib/auth";

/** Gates every /admin/* route except the login page itself behind the admin session cookie. */
export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  if (pathname === "/admin/login") {
    return NextResponse.next();
  }

  const cookie = request.cookies.get(ADMIN_SESSION_COOKIE)?.value;
  const expected = await expectedSessionToken();

  if (cookie !== expected) {
    const loginUrl = new URL("/admin/login", request.url);
    loginUrl.searchParams.set("from", pathname);
    return NextResponse.redirect(loginUrl);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/admin/:path*"],
};
