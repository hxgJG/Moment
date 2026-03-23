package service

import (
	"errors"

	"github.com/moment-server/moment-server/internal/model"
	"github.com/moment-server/moment-server/internal/repository"
	"github.com/moment-server/moment-server/pkg/jwt"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

var (
	ErrUserNotFound       = errors.New("user not found")
	ErrInvalidPassword    = errors.New("invalid password")
	ErrUserAlreadyExists   = errors.New("user already exists")
	ErrInvalidRefreshToken = errors.New("invalid refresh token")
)

// AuthService 认证服务
type AuthService struct {
	userRepo *repository.UserRepository
}

// NewAuthService 创建认证服务
func NewAuthService() *AuthService {
	return &AuthService{
		userRepo: repository.NewUserRepository(),
	}
}

// RegisterRequest 注册请求
type RegisterRequest struct {
	Username string `json:"username" binding:"required,min=3,max=50"`
	Password string `json:"password" binding:"required,min=6,max=100"`
	Nickname string `json:"nickname" binding:"max=100"`
}

// LoginRequest 登录请求
type LoginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

// RefreshRequest 刷新Token请求
type RefreshRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

// TokenResponse Token响应
type TokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	TokenType    string `json:"token_type"`
	ExpiresIn    int    `json:"expires_in"`
}

// Register 注册
func (s *AuthService) Register(req *RegisterRequest) (*TokenResponse, error) {
	// 检查用户是否已存在
	_, err := s.userRepo.FindByUsername(req.Username)
	if err == nil {
		return nil, ErrUserAlreadyExists
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}

	// 加密密码
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	// 创建用户
	user := &model.User{
		Username: req.Username,
		Password: string(hashedPassword),
		Nickname: req.Nickname,
		Status:   int8(model.UserStatusEnabled),
	}

	if err := s.userRepo.Create(user); err != nil {
		return nil, err
	}

	// 生成Token
	return s.generateTokenResponse(user)
}

// Login 登录
func (s *AuthService) Login(req *LoginRequest) (*TokenResponse, error) {
	// 查找用户
	user, err := s.userRepo.FindByUsername(req.Username)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}

	// 验证密码
	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)); err != nil {
		return nil, ErrInvalidPassword
	}

	// 检查用户状态
	if !user.IsEnabled() {
		return nil, ErrUserNotFound
	}

	// 生成Token
	return s.generateTokenResponse(user)
}

// RefreshToken 刷新Token
func (s *AuthService) RefreshToken(req *RefreshRequest) (*TokenResponse, error) {
	// 解析refresh token
	claims, err := jwt.GetManager().ParseToken(req.RefreshToken)
	if err != nil {
		return nil, ErrInvalidRefreshToken
	}

	// 验证refresh token的subject
	if claims.Subject != "refresh" {
		return nil, ErrInvalidRefreshToken
	}

	// 查找用户
	user, err := s.userRepo.FindByID(claims.UserID)
	if err != nil {
		return nil, ErrInvalidRefreshToken
	}

	if !user.IsEnabled() {
		return nil, ErrInvalidRefreshToken
	}

	// 生成新Token
	return s.generateTokenResponse(user)
}

func (s *AuthService) generateTokenResponse(user *model.User) (*TokenResponse, error) {
	accessToken, refreshToken, err := jwt.GetManager().GenerateTokenPair(user.ID, user.Username, "user")
	if err != nil {
		return nil, err
	}

	return &TokenResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		TokenType:    "Bearer",
		ExpiresIn:    7200,
	}, nil
}
