using SeriLovers.API.Models;

namespace SeriLovers.API.Interfaces
{
    public interface IActorService
    {
        List<Actor> GetAll();
        Actor? GetById(int id);
        void Add(Actor actor);
        void Update(Actor actor);
        void Delete(int id);
    }
}
