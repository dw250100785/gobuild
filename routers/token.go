package routers

import (
	"net/http"

	"github.com/Unknwon/macaron"
	"github.com/gobuild/gobuild/models"
	"github.com/gobuild/gobuild/models/github"
	"github.com/gobuild/gobuild/models/goutils"
	"github.com/gobuild/oauth2"
)

func Build(tokens oauth2.Tokens, ctx *macaron.Context, req *http.Request) {
	gh := github.New(tokens.Access())
	user, err := gh.User()
	if err != nil {
		ctx.Error(500, err.Error())
		return
	}

	muser := &models.User{
		Name:        user.Name,
		Email:       user.Email,
		GithubToken: tokens.Access(),
		Admin:       false,
	}
	models.DB.Insert(muser)

	// repos
	var repos []*github.Repository
	reposKey := "orgs:" + user.Login + ":repos"
	if !rdx.Exists(reposKey).Val() || req.FormValue("refresh") != "" {
		var err error
		repos, err = gh.Repositories()
		if err != nil {
			ctx.Error(500, err.Error())
			return
		}
		for _, repo := range repos {
			rdx.HMSet(reposKey, repo.Fullname, "")
		}
	} else {
		for _, repoName := range rdx.HKeys(reposKey).Val() {
			repos = append(repos, &github.Repository{
				Fullname: repoName,
			})
		}
	}

	// token
	rdx.Set("user:"+user.Login+":github_token", tokens.Access(), 0)
	tokenKey := "user:" + user.Login + ":token"
	if !rdx.Exists(tokenKey).Val() {
		rdx.Set(tokenKey, "gr"+goutils.RandNString(40), 0)
	}
	token := rdx.Get(tokenKey).Val()

	rdx.Set("token:"+token+":user", user.Login, 0)
	ctx.Data["User"] = user
	ctx.Data["Token"] = token
	ctx.Data["Repos"] = repos
	ctx.HTML(200, "build")
}
