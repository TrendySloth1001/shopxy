import prisma from '../../infra/db/prisma.js';

export class UsersService {
  async createUser(data: { email: string; name?: string }) {
    return prisma.user.create({ data });
  }

  async listUsers() {
    return prisma.user.findMany({ orderBy: { id: 'asc' } });
  }

  async getUserById(id: number) {
    return prisma.user.findUnique({ where: { id } });
  }

  async updateUser(
    id: number,
    data: { email?: string; name?: string }
  ) {
    return prisma.user.update({ where: { id }, data });
  }

  async deleteUser(id: number) {
    return prisma.user.delete({ where: { id } });
  }
}

export const usersService = new UsersService();
