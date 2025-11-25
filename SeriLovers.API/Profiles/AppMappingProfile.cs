using AutoMapper;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using System.Collections.Generic;
using System.Linq;

namespace SeriLovers.API.Profiles
{
    public class AppMappingProfile : Profile
    {
        public AppMappingProfile()
        {
            CreateMap<Actor, ActorDto>()
                .ForMember(dest => dest.Age, opt => opt.MapFrom(src => 
                    src.DateOfBirth.HasValue 
                        ? (int?)(DateTime.UtcNow.Year - src.DateOfBirth.Value.Year - 
                            (DateTime.UtcNow.DayOfYear < src.DateOfBirth.Value.DayOfYear ? 1 : 0))
                        : null))
                .ForMember(dest => dest.SeriesCount, opt => opt.MapFrom(src => 
                    src.SeriesActors != null ? src.SeriesActors.Count() : 0));
            CreateMap<ActorUpsertDto, Actor>();
            CreateMap<Genre, GenreDto>();
            CreateMap<GenreUpsertDto, Genre>();
            CreateMap<Episode, EpisodeDto>();
            CreateMap<Season, SeasonDto>()
                .ForMember(dest => dest.Episodes, opt => opt.MapFrom(src => src.Episodes ?? new List<Episode>()));
            CreateMap<SeasonUpsertDto, Season>();

            CreateMap<Series, SeriesDto>()
                .ForMember(dest => dest.Genres, opt => opt.MapFrom(src => src.SeriesGenres.Select(sg => sg.Genre.Name)))
                .ForMember(dest => dest.Actors, opt => opt.MapFrom(src => src.SeriesActors.Select(sa => sa.Actor)))
                .ForMember(dest => dest.RatingsCount, opt => opt.MapFrom(src => src.RatingsCount))
                .ForMember(dest => dest.WatchlistsCount, opt => opt.MapFrom(src => src.WatchlistsCount));

            CreateMap<Series, SeriesDetailDto>()
                .ForMember(dest => dest.Genres, opt => opt.MapFrom(src => src.SeriesGenres.Select(sg => sg.Genre != null ? sg.Genre.Name : string.Empty).Where(name => !string.IsNullOrEmpty(name))))
                .ForMember(dest => dest.Actors, opt => opt.MapFrom(src => src.SeriesActors.Select(sa => sa.Actor)))
                .ForMember(dest => dest.Seasons, opt => opt.MapFrom(src => src.Seasons ?? new List<Season>()))
                .ForMember(dest => dest.Ratings, opt => opt.MapFrom(src => src.Ratings ?? new List<Rating>()))
                .ForMember(dest => dest.Watchlists, opt => opt.MapFrom(src => src.Watchlists ?? new List<Watchlist>()));

            CreateMap<Rating, RatingDto>();
            CreateMap<Watchlist, WatchlistDto>()
                .ForMember(dest => dest.Series, opt => opt.MapFrom(src => src.Series));
            CreateMap<FavoriteCharacter, FavoriteCharacterDto>()
                .ForMember(dest => dest.ActorName, opt => opt.MapFrom(src => src.Actor != null ? $"{src.Actor.FirstName} {src.Actor.LastName}" : null))
                .ForMember(dest => dest.SeriesTitle, opt => opt.MapFrom(src => src.Series != null ? src.Series.Title : null));
            CreateMap<FavoriteCharacterCreateDto, FavoriteCharacter>();
            CreateMap<FavoriteCharacterUpdateDto, FavoriteCharacter>();
            CreateMap<RecommendationLog, RecommendationLogDto>()
                .ForMember(dest => dest.UserEmail, opt => opt.MapFrom(src => src.User != null ? src.User.Email : null))
                .ForMember(dest => dest.SeriesTitle, opt => opt.MapFrom(src => src.Series != null ? src.Series.Title : null));
            CreateMap<RecommendationLogCreateDto, RecommendationLog>();
            CreateMap<RecommendationLogUpdateDto, RecommendationLog>();

            CreateMap<SeriesUpsertDto, Series>()
                .ForMember(dest => dest.SeriesGenres, opt => opt.MapFrom(src => 
                    src.GenreIds != null && src.GenreIds.Any() 
                        ? src.GenreIds.Select(id => new SeriesGenre { GenreId = id }).ToList()
                        : new List<SeriesGenre>()))
                .ForMember(dest => dest.SeriesActors, opt => opt.Ignore())
                .ForMember(dest => dest.Genres, opt => opt.Ignore())
                .ForMember(dest => dest.Actors, opt => opt.Ignore())
                .AfterMap((src, dest) =>
                {
                    // Build SeriesActors from ActorIds and Actors list
                    var actorDict = new Dictionary<int, SeriesActor>();
                    
                    // First add ActorIds (without role names)
                    if (src.ActorIds != null && src.ActorIds.Any())
                    {
                        foreach (var id in src.ActorIds)
                        {
                            if (!actorDict.ContainsKey(id))
                            {
                                actorDict[id] = new SeriesActor { ActorId = id, RoleName = null };
                            }
                        }
                    }
                    
                    // Then add/update with Actors list (which may have role names)
                    if (src.Actors != null && src.Actors.Any())
                    {
                        foreach (var a in src.Actors)
                        {
                            actorDict[a.ActorId] = new SeriesActor { ActorId = a.ActorId, RoleName = a.RoleName };
                        }
                    }
                    
                    dest.SeriesActors = actorDict.Values.ToList();
                });

            CreateMap<RatingCreateDto, Rating>();
            CreateMap<WatchlistCreateDto, Watchlist>();
            CreateMap<EpisodeUpsertDto, Episode>();
        }
    }
}

