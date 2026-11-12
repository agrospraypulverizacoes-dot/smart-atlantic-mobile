export const BASE_URL = 'https://smartfarm.atlanticdrones.com.br';
export type Resource = 'plots' | 'devices' | 'operations';
export async function api(path: string, body?: unknown): Promise<any> {
  const timer = new AbortController();
  const timeout = setTimeout(() => timer.abort(), 15000);
  try {
    const response = await fetch(BASE_URL + path, {
      method: body === undefined ? 'GET' : 'POST',
      headers: { 'Accept': 'application/json', 'Content-Type': 'application/json' },
      credentials: 'include', signal: timer.signal,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(String(result.detail || result.message || 'Erro HTTP ' + response.status));
    return result;
  } finally { clearTimeout(timeout); }
}
export const me = () => api('/api/v1/auth/me');
export const login = (username: string, password: string) => api('/api/v1/auth/login', { username, password });
export const logout = () => api('/api/v1/auth/logout', {});
export const list = (resource: Resource) => api('/api/v1/eav/read/' + resource, { pageIndex: 1, pageSize: 30, ...(resource === 'operations' ? {searchType: 2} : {}) });
