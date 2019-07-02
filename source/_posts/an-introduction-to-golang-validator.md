---
title: Golang validator 详解
date: 2019-06-16 17:04:28
tags: [Golang,基础知识]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/110
---
<!-- en_title: an-introduction-to-golang-validator -->

在 Web 应用中，有一块内容非常重要，却很容易被我们忽略：**参数验证**，忘了之后常常会给我们造成大量的处理错误问题，甚至直接造成应用崩溃。之前我在 [你的团队需要更好的 API 文档流程][blog_85] 提到过，[Joi][joi] 的验证非常好用，可以帮助我们验证客户端用户的上传数据以及返回数据，而在 Golang 中，我们该如何做呢？

<!-- more -->

### 如果需要我们自己验证

显然，肯定是有的，而且跟我们又爱又恨的 reflect 有关系，因为对于强类型语言来说，如果没有[元编程][meta_prog]的帮助，对于数据的验证会变得非常难受：

```go
if strings.Trim(mobile, " ") == "" {
  return nil, ErrEmptyParams
}
mobileRegex := regexp.MustCompile(`^1\d{10}$`)
if !mobileRegex.MatchString(mobile) {
  return nil, ErrInvalidMobile
}
```

上面这类似的代码会充斥在你的业务逻辑处理当中，非常不优雅，即使我们可以把常见的验证封装，也不能避免我们这样的情况，充其量只能缩短验证的代码行数而已。

回过头来，当我们有了 reflect 的帮助，验证就会变得非常简单，我们只要在 `Struct Tag` 中，声明字段的验证要求，剩下的，就交给框架或者中间件去统一处理即可，非常简单而又优雅，并且容易维护。

于是，我们今天要介绍的主角就可以出场了：[go-playground/validator][validator]，它目前最新的版本是 v9，以下内容会跟之前的 v8 版本做一些对比。

### 字段验证

这是最主要的验证，我们常见的验证就有用户邮箱、非空、最大最小，长度限制等等验证。

```go
type Test struct {
  Email string `validate:"email"`
  Size  int    `validate:"max=10,min=1"`
}

err := validate.Struct(&Test{"wrong_email", 100})

if err != nil {
   // handler the error
}
```

其它内容，过于冗长，不方便搬到这里，还是请看[文档][validator-doc]。

### 跨字段以及跨 Struct 验证

对于字段之间，甚至跨 Struct 之间的字段验证，它都可以做到，主要有：

-   `eqfield=Field`: 必须等于 Field 的值； 
-   `nefield=Field`: 必须不等于 Field 的值；
-   `gtfield=Field`: 必须大于 Field 的值；
-   `gtefield=Field`: 必须大于等于 Field 的值；
-   `ltfield=Field`: 必须小于 Field 的值；
-   `ltefield=Field`: 必须小于等于 Field 的值；
-   `eqcsfield=Other.Field`: 必须等于 struct Other 中 Field 的值； 
-   `necsfield=Other.Field`: 必须不等于 struct Other 中 Field 的值； 
-   `gtcsfield=Other.Field`: 必须大于 struct Other 中 Field 的值； 
-   `gtecsfield=Other.Field`: 必须大于等于 struct Other 中 Field 的值； 
-   `ltcsfield=Other.Field`: 必须小于 struct Other 中 Field 的值； 
-   `ltecsfield=Other.Field`: 必须小于等于 struct Other 中 Field 的值； 

是不是看晕了？没关系，这些 tag 是有规律的，仔细看看就不难发现，他们组成就是 **比较符号 + 是否跨 Struct(cross struct) + field**，而比较符号就只有 6 种：

-   `eq`:  Equal，等于；
-   `ne`:  Non Equal，不等于；
-   `gt`:  Great than，大于；
-   `gte`: Great than equal，大于等于；
-   `lt`:  Less than，小于；
-   `lte`: Less than equal，小于等于；

这样，是不是好记忆一点？

它的用法也是简单明了，直接在后面加上要比较的字段即可：

```go
type Test struct {
	StartAt time.Time `validate:"required"`
	EndAt   time.Time `validate:"required,gtfield=StartAt"`
}
```

另外还有几个挺有用的 Tag：

-   `required_with=Field1 Field2`: 在 Field1 或者 Field2 存在时，必须；
-   `required_with_all=Field1 Field2`: 在 Field1 与 Field2 都存在时，必须；
-   `required_without=Field1 Field2`: 在 Field1 或者 Field2 不存在时，必须；
-   `required_without_all=Field1 Field2`: 在 Field1 与 Field2 都存在时，必须；

更多还是请看[文档][validator-doc]。

### 自定义字段验证

在 v9 之前，validator 的自定义验证一直是这样的：

```go
func customFunc(
	v *validator.Validate, topStruct reflect.Value, currentStructOrField reflect.Value,
	field reflect.Value, fieldType reflect.Type, fieldKind reflect.Kind, param string,
) bool {
	if str, ok := field.Interface().(string); ok {
		return str != "invalid"
	}
	return false
}
```

显得冗长，不优雅，在 v9 经过重新设计以后，我们就可以通过更加优雅的方式来定义自己的字段验证了：

```go
func customFunc(fl validator.FieldLevel) bool {
	return fl.Field().String() != "invalid"
}
```

而在我们使用之前，需要注册相应的 Tag：

```go
validate := validator.New()
validate.RegisterValidation("my-validate", customFunc)
```

### 错误提示

在 v9 之前，我们得到的错误提示非常难看：

    Key: "" Error:Field validation for "" failed on the "email" tag

这的确能告诉我们哪里出错了，只是，对于使用我们提供的 API 的开发者而言，这种错误就会显得过于生硬而不友好。

于是，v9 提供了对于具体错误的翻译功能。我们可以从[例子][validator-trans]中看到详细的用法：

```go
// translator_example.go

import (
	"fmt"

	"github.com/go-playground/locales/en"
	ut "github.com/go-playground/universal-translator"
	"gopkg.in/go-playground/validator.v9"
	en_translations "gopkg.in/go-playground/validator.v9/translations/en"
)

en := en.New()
uni = ut.New(en, en)
trans, _ := uni.GetTranslator("en")

validate = validator.New()
en_translations.RegisterDefaultTranslations(validate, trans)

err := validate.Struct(user)
if err != nil {
	errs := err.(validator.ValidationErrors)
	fmt.Println(errs.Translate(trans))
}
```

经过这样的处理之后，我们可以返回给调用者更加优雅的提示。

### 与 gin 的配合使用

gin 是使用 validator 非常频繁的 Web 框架，但是它对于升级的 v9，一直保持比较谨慎的态度，因为担心它会对 gin 用户的应用造成一些不兼容的改变，在纠结了将近两年多之后，终于决定在 1.5 的里程碑中发布了。<sup>[1]</sup>

不过，其实 validator 的开发者早就给出了 gin 的[升级方案][v8_to_v9]，我们可以替换掉 `binding` 的 validator 即可（**这里又体现了 go interface 的设计合理性了：它只是一个抽象，你可以用任何实现去替换它**）。

```go
package main

import "github.com/gin-gonic/gin/binding"

func main() {
	binding.Validator = new(v9Validator)
	if v, ok := binding.Validator.Engine().(*validator.Validate); ok {
	   // 注册 Translator，参照上面的 translator_example.go
	  // 注册自定义字段验证 Validator
	  // 注册自定义翻译器 Translator
	}
	...
}
```

而对于错误处理，我们可以写一个中间件去处理，这里需要特别注意的是，`UniversalTranslator` 中获得的 Translator 是一个 interface，而它的实例是一个指针，因此我们不能通过重建一个 `UniversalTranslator` 来翻译错误，我们可以将它作为一个参数传入到错误处理逻辑中去：

```go
// error_handlers.go

type ErrorHandler struct {
	uni *ut.UniversalTranslator
}

func NewErrorHandler(uni *ut.UniversalTranslator) *ErrorHandler {
	return &ErrorHandler{
		uni: uni,
	}
}

func (h *ErrorHandler) HandleErrors(c *gin.Context) {
	c.Next()

	errorToPrint := c.Errors.ByType(gin.ErrorTypePublic).Last()
	if errorToPrint != nil {
		if errs, ok := errorToPrint.Err.(validator.ValidationErrors); ok {
			trans,_ := h.uni.GetTranslator("zh") // 这里也可以通过获取 HTTP Header 中的 Accept-Language 来获取用户的语言设置
			c.JSON(http.StatusBadRequest, gin.H{
				"errors":  errs.Translate(trans),
			})
			return
		}
		
		// deal with other errors ...
	}
}
```

### Ref

1.  [upgrade validator version to v9][1]

[1]: https://github.com/gin-gonic/gin/pull/1015

[validator]: https://github.com/go-playground/validator

[validator-doc]: https://godoc.org/gopkg.in/go-playground/validator.v9

[validator-trans]: https://github.com/go-playground/validator/blob/v9/_examples/translations/main.go

[v8_to_v9]: https://github.com/go-playground/validator/blob/v9/_examples/gin-upgrading-overriding/v8_to_v9.go

[joi]: https://github.com/hapijs/joi

[blog_85]: https://github.com/xizhibei/blog/issues/85

[meta_prog]: https://zh.wikipedia.org/wiki/%E5%85%83%E7%BC%96%E7%A8%8B


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/110 ，欢迎 Star 以及 Watch

{% post_link footer %}
***